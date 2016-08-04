module Lightstreamer
  # This class is responsible for managing a Lightstreamer session, and along with the {Subscription} class forms the
  # primary API for working with Lightstreamer. Start by calling {#initialize} with the desired server URL and other
  # options, then call {#connect} to initiate the session. Once connected create subscriptions using
  # {#build_subscription} and then start streaming data by calling {Subscription#start} or {#bulk_subscription_start}.
  # See the {Subscription} class for details on how to consume the streaming data as it arrives.
  class Session
    # The URL of the Lightstreamer server to connect to. Set by {#initialize}.
    #
    # @return [String]
    attr_reader :server_url

    # The username to connect to the Lightstreamer server with. Set by {#initialize}.
    #
    # @return [String, nil]
    attr_reader :username

    # The password to connect to the Lightstreamer server with. Set by {#initialize}.
    #
    # @return [String, nil]
    attr_reader :password

    # The name of the adapter set to request from the Lightstreamer server. Set by {#initialize}.
    #
    # @return [String, nil]
    attr_reader :adapter_set

    # The server-side bandwidth constraint on data usage, expressed in kbps. If this is zero then no limit is applied.
    #
    # @return [Float]
    attr_reader :requested_maximum_bandwidth

    # Whether polling mode is enabled. By default long-running HTTP connections will be used to stream incoming data,
    # but if polling is enabled then repeated short polling requests will be used instead. Polling may work better if
    # there is intermediate buffering on the network that affects timely delivery of data on long-running streaming
    # connections. The polling mode for a connected session can be changed by setting {#polling_enabled} and then
    # calling {#force_rebind}.
    #
    # @return [Boolean]
    attr_accessor :polling_enabled

    # Initializes this new Lightstreamer session with the passed options.
    #
    # @param [Hash] options The options to create the session with.
    # @option options [String] :server_url The URL of the Lightstreamer server. Required.
    # @option options [String] :username The username to connect to the server with.
    # @option options [String] :password The password to connect to the server with.
    # @option options [String] :adapter_set The name of the adapter set to request from the server.
    # @option options [Float] :requested_maximum_bandwidth. The server-side bandwidth constraint on data usage,
    #                 expressed in kbps. Defaults to zero which means no limit is applied.
    # @option options [Boolean] :polling_enabled Whether polling mode is enabled. See {#polling_enabled} for details.
    #                 Defaults to `false`.
    def initialize(options = {})
      @mutex = Mutex.new

      @server_url = options.fetch :server_url
      @username = options[:username]
      @password = options[:password]
      @adapter_set = options[:adapter_set]
      @requested_maximum_bandwidth = options[:requested_maximum_bandwidth].to_f
      @polling_enabled = options[:polling_enabled]

      @subscriptions = []
      @callbacks = { on_message_result: [], on_error: [] }
    end

    # Connects a new Lightstreamer session using the details passed to {#initialize}. If an error occurs then
    # a {LightstreamerError} subclass will be raised.
    def connect
      return if @stream_connection

      @stream_connection = StreamConnection.new self
      @stream_connection.connect

      create_processing_thread
    rescue
      @stream_connection = nil
      raise
    end

    # Returns whether this Lightstreamer session is currently connected and has an active stream connection.
    #
    # @return [Boolean]
    def connected?
      !@stream_connection.nil?
    end

    # Returns the ID of the currently active Lightstreamer session, or `nil` if there is no active session.
    #
    # @return [String, nil]
    def session_id
      @stream_connection && @stream_connection.session_id
    end

    # Disconnects this Lightstreamer session and terminates the session on the server. All worker threads are exited.
    def disconnect
      control_request :destroy if @stream_connection

      @processing_thread.join 5 if @processing_thread
    ensure
      @stream_connection.disconnect if @stream_connection
      @processing_thread.exit if @processing_thread

      @subscriptions.each { |subscription| subscription.instance_variable_set :@active, false }

      @processing_thread = @stream_connection = nil
    end

    # Requests that the Lightstreamer server terminate the currently active stream connection and require that a new
    # stream connection be initiated by the client. The Lightstreamer server requires closure and re-establishment of
    # the stream connection periodically during normal operation, this method just allows such a reconnection to be
    # requested explicitly by the client. This is particularly useful after {#polling_enabled} has been changed because
    # it forces the stream connection to rebind using the new setting. If an error occurs then a {LightstreamerError}
    # subclass will be raised.
    def force_rebind
      control_request :force_rebind if @stream_connection
    end

    # Builds a new subscription for this session with the specified options. Note that ths does not activate the
    # subscription, {Subscription#start} must be called to actually start streaming the subscription's data. See the
    # {Subscription} class for more details.
    #
    # @param [Hash] options The options to create the subscription with.
    # @option options [Array] :items The names of the items to subscribe to. Required.
    # @option options [Array] :fields The names of the fields to subscribe to on the items. Required.
    # @option options [:command, :distinct, :merge, :raw] :mode The operation mode of the subscription. Required.
    # @option options [String] :adapter The name of the data adapter from this session's adapter set that should be
    #                 used. If this is not set or is set to `nil` then the default data adapter will be used.
    # @option options [String] :selector The selector for table items. Optional.
    # @option options [Float, :unfiltered] :maximum_update_frequency The maximum number of updates the subscription
    #                 should receive per second. Defaults to zero which means there is no limit on the update frequency.
    #                 If set to `:unfiltered` then unfiltered streaming will be used for the subscription and it is
    #                 possible for overflows to occur (see {Subscription#on_overflow}).
    #
    # @return [Subscription] The new subscription.
    def build_subscription(options)
      subscription = Subscription.new self, options

      @mutex.synchronize { @subscriptions << subscription }

      subscription
    end

    # Stops the specified subscription and removes it from this session. If an error occurs then a {LightstreamerError}
    # subclass will be raised. To just stop a subscription with the option of restarting it at a later date call
    # {Subscription#stop} on the subscription itself.
    #
    # @param [Subscription] subscription The subscription to stop and remove from this session.
    def remove_subscription(subscription)
      subscription.stop

      @mutex.synchronize { @subscriptions.delete subscription }
    end

    # This method performs a bulk {Subscription#start} on all the passed subscriptions. Calling {Subscription#start} on
    # each subscription individually would also work but requires a separate POST request to be sent for every
    # subscription, whereas this request starts all of the passed subscriptions in a single POST request which is
    # significantly faster for a large number of subscriptions. The return value is an array with one entry per
    # subscription and indicates the error state returned by the server for that subscription's start request, or `nil`
    # if no error occurred.
    #
    # @param [Array<Subscription>] subscriptions The subscriptions to start.
    #
    # @return [Array<LightstreamerError, nil>]
    def bulk_subscription_start(*subscriptions)
      request_bodies = subscriptions.map do |subscription|
        args = subscription.start_control_request_args
        PostRequest.request_body({ LS_session: session_id, LS_op: args.first }.merge(args[1]))
      end

      errors = PostRequest.bulk_execute control_request_url, request_bodies

      # Set @active to true on all subscriptions that did not have an error
      errors.each_with_index do |error, index|
        subscriptions[index].instance_variable_set :@active, true if error.nil?
      end
    end

    # Sets the server-side bandwidth constraint on data usage for this session, expressed in kbps. A value of zero
    # means no limit will be applied. If an error occurs then a {LightstreamerError} subclass will be raised.
    #
    # @param [Float] bandwidth The new requested maximum bandwidth, expressed in kbps.
    def requested_maximum_bandwidth=(bandwidth)
      control_request :constrain, LS_requested_max_bandwidth: bandwidth if connected?
      @requested_maximum_bandwidth = bandwidth.to_f
    end

    # Sends a custom message to the Lightstreamer server. Message sending can be done synchronously or asynchronously.
    # By default the message will be sent synchronously, i.e. the message will be processed by the server and if an
    # error occurs a {LightstreamerError} subclass will be raised immediately. However, if the `:async` option is true
    # then the message will be sent asynchronously, and the result of the message send will be reported to all callbacks
    # that have been registered via {#on_message_result}. If `:async` is set to `true` then the `:sequence` and
    # `:number` options must also be specified.
    #
    # @param [String] message The message to send to the Lightstreamer server.
    # @param [Hash] options The options that control messages sent asynchronously.
    # @option options [Boolean] :async Whether to send the message asynchronously. Defaults to `false`.
    # @option options [String] :sequence The alphanumeric identifier that identifies a subset of messages that are to
    #                 be processed in sequence based on the `:number` given to them. If the special
    #                 `"UNORDERED_MESSAGES"` sequence is used then the associated messages are processed immediately,
    #                 possibly concurrently, with no ordering constraint.
    # @option options [Fixnum] :number The progressive number of this message within its sequence. Should start at 1.
    # @option options [Float] :max_wait The maximum time the server can wait before processing this message if one or
    #                 more of the preceding messages in the same sequence have not been received. If not specified then
    #                 a timeout is assigned by the server.
    def send_message(message, options = {})
      url = URI.join(@stream_connection.control_address, '/lightstreamer/send_message.txt').to_s

      query = { LS_session: session_id, LS_message: message }
      query[:LS_sequence] = options.fetch(:sequence) if options[:async]
      query[:LS_msg_prog] = options.fetch(:number) if options[:async]
      query[:LS_max_wait] = options[:max_wait] if options[:max_wait]

      PostRequest.execute url, query
    end

    # Adds the passed block to the list of callbacks that will be run when the outcome of one or more asynchronous
    # message sends arrive. The block will be called on a worker thread and so the code that is run by the block must be
    # thread-safe. The arguments passed to the block are `|sequence, numbers, error|`.
    #
    # @param [Proc] callback The callback that is to be run.
    def on_message_result(&callback)
      @mutex.synchronize { @callbacks[:on_message_result] << callback }
    end

    # Sends a request to this session's control connection. If an error occurs then a {LightstreamerError} subclass will
    # be raised.
    #
    # @param [Symbol] operation The control operation to perform.
    # @param [Hash] options The options to send with the control request.
    def control_request(operation, options = {})
      PostRequest.execute control_request_url, options.merge(LS_session: session_id, LS_op: operation)
    end

    # Adds the passed block to the list of callbacks that will be run when this session encounters an error on its
    # processing thread caused by an error with the steam connection. The block will be called on a worker thread and so
    # the code that is run by the block must be thread-safe. The argument passed to the block is `|error|`, which will
    # be a {LightstreamerError} subclass detailing the error that occurred.
    #
    # @param [Proc] callback The callback that is to be run.
    def on_error(&callback)
      @mutex.synchronize { @callbacks[:on_error] << callback }
    end

    private

    def control_request_url
      URI.join(@stream_connection.control_address, '/lightstreamer/control.txt').to_s
    end

    # Starts the processing thread that reads and processes incoming data from the stream connection.
    def create_processing_thread
      @processing_thread = Thread.new do
        Thread.current.abort_on_exception = true

        loop { break unless processing_thread_tick @stream_connection.read_line }

        @processing_thread = @stream_connection = nil
      end
    end

    def processing_thread_tick(line)
      if line
        process_stream_line line
        true
      else
        @mutex.synchronize { @callbacks[:on_error].each { |callback| callback.call @stream_connection.error } }
        false
      end
    end

    # Processes a single line of incoming stream data. This method is always run on the processing thread.
    def process_stream_line(line)
      return if @mutex.synchronize { @subscriptions.any? { |subscription| subscription.process_stream_data line } }
      return if process_send_message_outcome line

      warn "Lightstreamer: unprocessed stream data '#{line}'"
    end

    # Attempts to process the passed line as a send message outcome message.
    def process_send_message_outcome(line)
      outcome = SendMessageOutcomeMessage.parse line
      return unless outcome

      @mutex.synchronize do
        @callbacks[:on_message_result].each do |callback|
          callback.call outcome.sequence, outcome.numbers, outcome.error
        end
      end

      true
    end
  end
end
