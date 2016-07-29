module Lightstreamer
  # This class is responsible for managing a Lightstreamer session, and along with the {Subscription} class forms the
  # primary API for working with Lightstreamer.
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

    # If an error occurs on the stream connection that causes the session to terminate then details of the error will be
    # stored in this attribute. If the session is terminated as a result of calling {#disconnect} then the error will be
    # {SessionEndError}.
    #
    # @return [LightstreamerError, nil]
    attr_reader :error

    # The server-side bandwidth constraint on data usage, expressed in kbps. If this is zero then no limit is applied.
    #
    # @return [Float]
    attr_reader :requested_maximum_bandwidth

    # Initializes this new Lightstreamer session with the passed options.
    #
    # @param [Hash] options The options to create the session with.
    # @option options [String] :server_url The URL of the Lightstreamer server. Required.
    # @option options [String] :username The username to connect to the server with.
    # @option options [String] :password The password to connect to the server with.
    # @option options [String] :adapter_set The name of the adapter set to request from the server.
    # @option options [Float] :requested_maximum_bandwidth. The server-side bandwidth constraint on data usage,
    #                 expressed in kbps. Defaults to zero which means no limit is applied.
    def initialize(options = {})
      @subscriptions = []
      @subscriptions_mutex = Mutex.new

      @server_url = options.fetch :server_url
      @username = options[:username]
      @password = options[:password]
      @adapter_set = options[:adapter_set]
      @requested_maximum_bandwidth = options[:requested_maximum_bandwidth].to_f
    end

    # Connects a new Lightstreamer session using the details passed to {#initialize}. If an error occurs then
    # a {LightstreamerError} subclass will be raised.
    def connect
      return if @stream_connection

      @error = nil

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

      @subscriptions.each do |subscription|
        subscription.instance_variable_set :@active, false
      end

      @processing_thread = @stream_connection = nil
    end

    # Requests that the Lightstreamer server terminate the currently active stream connection and require that a new
    # stream connection be initiated by the client. The Lightstreamer server requires closure and re-establishment of
    # the stream connection periodically during normal operation, this method just allows such a reconnection to be
    # requested explicitly by the client. If an error occurs then a {LightstreamerError} subclass will be raised.
    def force_rebind
      return unless @stream_connection

      control_request :force_rebind
    end

    # Builds a new subscription for this session with the specified options. Note that ths does not activate the
    # subscription, {Subscription#start} must be called to actually start streaming the subscription's data. See the
    # {Subscription} class for more details.
    #
    # @param [Hash] options The options to create the subscription with.
    # @option options [Array] :items The names of the items to subscribe to. Required.
    # @option options [Array] :fields The names of the fields to subscribe to on the items. Required.
    # @option options [:distinct, :merge] :mode The operation mode of the subscription. Required.
    # @option options [String] :adapter The name of the data adapter from this session's adapter set that should be
    #                 used. If `nil` then the default data adapter will be used.
    # @option options [String] :selector The selector for table items. Optional.
    # @option options [Float, :unfiltered] :maximum_update_frequency The maximum number of updates the subscription
    #                 should receive per second. Defaults to zero which means there is no limit on the update frequency.
    #                 If set to `:unfiltered` then unfiltered streaming will be used for the subscription and it is
    #                 possible for overflows to occur (see {Subscription#on_overflow}).
    #
    # @return [Subscription] The new subscription.
    def build_subscription(options)
      subscription = Subscription.new self, options

      @subscriptions_mutex.synchronize { @subscriptions << subscription }

      subscription
    end

    # Stops the specified subscription and removes it from this session. If an error occurs then a {LightstreamerError}
    # subclass will be raised. To just stop a subscription with the option of restarting it at a later date call
    # {Subscription#stop} on the subscription itself.
    def remove_subscription(subscription)
      raise ArgumentError, 'Unknown subscription' unless subscription.session == self

      subscription.stop

      @subscriptions_mutex.synchronize do
        @subscriptions.delete subscription
        subscription.instance_variable_set :@session, nil
      end
    end

    # Sets the server-side bandwidth constraint on data usage for this session, expressed in kbps. A value of zero
    # means no limit will be applied. If an error occurs then a {LightstreamerError} subclass will be raised.
    #
    # @param [Float] bandwidth The new requested maximum bandwidth, expressed in kbps.
    def requested_maximum_bandwidth=(bandwidth_kbps)
      control_request :constrain, LS_requested_max_bandwidth: bandwidth_kbps if @stream_connection
      @requested_maximum_bandwidth = bandwidth_kbps.to_f
    end

    # Sends a request to the control connection. If an error occurs then a {LightstreamerError} subclass will be raised.
    #
    # @param [Symbol] operation The control operation to perform.
    # @param [Hash] options The options to send with the control request.
    #
    # @private
    def control_request(operation, options = {})
      return unless @stream_connection

      ControlConnection.execute @stream_connection.control_address, session_id, operation, options
    end

    private

    # Starts the processing thread that reads and processes incoming data from the stream connection.
    def create_processing_thread
      @processing_thread = Thread.new do
        Thread.current.abort_on_exception = true

        loop do
          line = @stream_connection.read_line

          break if line.nil?

          process_stream_data line unless line.empty?
        end

        # The stream connection has terminated so the session is assumed to be over
        @error = @stream_connection.error
        @processing_thread = @stream_connection = nil
      end
    end

    # Processes a single line of incoming stream data by passing it to all the subscriptions until one
    # successfully processes it. This method is always run on the processing thread.
    def process_stream_data(line)
      was_processed = @subscriptions_mutex.synchronize do
        @subscriptions.detect do |subscription|
          subscription.process_stream_data line
        end
      end

      warn "Lightstreamer: unprocessed stream data '#{line}'" unless was_processed
    end
  end
end
