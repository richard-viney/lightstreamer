module Lightstreamer
  # This class is responsible for managing a Lightstreamer session, and along with the {Subscription} class is the
  # primary interface for working with Lightstreamer.
  class Session
    # @return [String] The URL of the Lightstreamer server to connect to. Set by {#initialize}.
    attr_reader :server_url

    # @return [String] The username to connect to the Lightstreamer server with. Set by {#initialize}.
    attr_reader :username

    # @return [String] The password to connect to the Lightstreamer server with. Set by {#initialize}.
    attr_reader :password

    # @return [String] The name of the adapter set to request from the Lightstreamer server. Set by {#initialize}.
    attr_reader :adapter_set

    # Initializes this new Lightstreamer session with the passed options.
    #
    # @param [Hash] options The options to create the session with.
    # @option options [String] :server_url The URL of the Lightstreamer server. Required.
    # @option options [String] :username The username to connect to the server with. Optional.
    # @option options [String] :password The password to connect to the server with. Optional.
    # @option options [String] :adapter_set The name of the adapter set to request from the server. Optional.
    def initialize(options = {})
      @subscriptions = []
      @subscriptions_mutex = Mutex.new

      @server_url = options.fetch :server_url
      @username = options[:username]
      @password = options[:password]
      @adapter_set = options[:adapter_set]
    end

    # Creates a new Lightstreamer session using the details passed to {#initialize}. If an error occurs then
    # {ProtocolError} will be raised.
    def connect
      @stream_connection = StreamConnection.new self
      @subscriptions = []

      first_line = @stream_connection.read_line

      if first_line == 'OK'
        @session_id = read_session_id
        create_control_connection
        create_processing_thread
      elsif first_line == 'ERROR'
        handle_connection_error
      end
    end

    # Subscribes this Lightstreamer session to the specified subscription.
    #
    # @param [Subscription] subscription The new subscription to subscribe to.
    def subscribe(subscription)
      subscription.clear_data

      @subscriptions_mutex.synchronize { @subscriptions << subscription }

      begin
        @control_connection.execute table: subscription.id, operation: :add, mode: subscription.mode,
                                    items: subscription.items, fields: subscription.fields,
                                    adapter: subscription.adapter
      rescue
        @subscriptions_mutex.synchronize { @subscriptions.delete subscription }
        raise
      end
    end

    # Unsubscribes this Lightstreamer session from the specified subscription.
    #
    # @param [Subscription] subscription The existing subscription to unsubscribe from.
    def unsubscribe(subscription)
      @subscriptions_mutex.synchronize do
        raise ArgumentError, 'Unknown subscription' unless @subscriptions.detect subscription
      end

      @control_connection.execute table: subscription.id, operation: :delete

      @subscriptions_mutex.synchronize { @subscriptions.delete subscription }
    end

    private

    # Parses the next line of data from the stream connection as the session ID and returns it.
    def read_session_id
      @stream_connection.read_line.match(/^SessionId:(.*)$/).captures.first
    end

    # Attempts to parses the next line of data from the stream connection as a custom control address and then uses this
    # address to create the control connection. Note that the control address is optional and if it is absent then
    # {#server_url} will be used instead of a custom control address.
    def create_control_connection
      match = @stream_connection.read_line.match(/^ControlAddress:(.*)$/)
      control_address = (match && match.captures.first) || server_url

      # The rest of the contents in the header is ignored, so read up until the blank line that marks its ending
      loop { break if @stream_connection.read_line == '' }

      # If the control URL doesn't have a schema then use the same schema as the server URL
      control_address = "#{URI(server_url).scheme}://#{control_address}" unless control_address.start_with? 'http'

      @control_connection = ControlConnection.new @session_id, control_address
    end

    # Starts the processing thread that reads and processes incoming data from the stream connection.
    def create_processing_thread
      @processing_thread = Thread.new do
        begin
          loop do
            process_stream_data @stream_connection.read_line
          end
        rescue StandardError => error
          warn "Lightstreamer: exception in processing thread: #{error}"
          exit 1
        end
      end
    end

    # Processes a single line of incoming stream data by passing it to all the active subscriptions until one
    # successfully processes it. This method is always run on the processing thread.
    def process_stream_data(line)
      was_processed = @subscriptions_mutex.synchronize do
        @subscriptions.detect do |subscription|
          subscription.process_stream_data line
        end
      end

      warn "Lightstreamer: unprocessed stream data '#{line}'" unless was_processed
    end

    # Handles a failure to establish a stream connection by reading off the error code and error message then raising
    # a {ProtocolError}.
    def handle_connection_error
      error_code = @stream_connection.read_line
      error_message = @stream_connection.read_line

      @stream_connection = nil
      @control_connection = nil

      raise ProtocolError.new(error_message, error_code)
    end
  end
end
