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
      return if @stream_connection

      create_stream_connection
      create_control_connection
      create_processing_thread
    rescue
      @stream_connection = nil
      raise
    end

    # Disconnects this session and shuts down its stream connection and processing threads.
    def disconnect
      @stream_connection.disconnect if @stream_connection

      if @processing_thread
        Thread.kill @processing_thread
        @processing_thread.join
      end

      @processing_thread = @stream_connection = @control_connection = nil
      @subscriptions = []
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

    # Returns whether the specified subscription is currently active on this session.
    #
    # @param [Subscription] subscription The subscription to return the status for.
    #
    # @return [Boolean] Whether the specified subscription is currently active on this session.
    def subscribed?(subscription)
      @subscriptions_mutex.synchronize { @subscriptions.include? subscription }
    end

    # Unsubscribes this Lightstreamer session from the specified subscription.
    #
    # @param [Subscription] subscription The existing subscription to unsubscribe from.
    def unsubscribe(subscription)
      raise ArgumentError, 'Unknown subscription' unless subscribed? subscription

      @control_connection.execute table: subscription.id, operation: :delete

      @subscriptions_mutex.synchronize { @subscriptions.delete subscription }
    end

    private

    def create_stream_connection
      @stream_connection = StreamConnection.new self
      @stream_connection.connect
    end

    def create_control_connection
      control_address = @stream_connection.control_address || server_url

      # If the control address doesn't have a schema then use the same schema as the server URL
      unless control_address.start_with? 'http'
        control_address = "#{URI(server_url).scheme}://#{control_address}"
      end

      @control_connection = ControlConnection.new @stream_connection.session_id, control_address
    end

    # Starts the processing thread that reads and processes incoming data from the stream connection.
    def create_processing_thread
      @processing_thread = Thread.new do
        loop do
          line = @stream_connection.read_line

          process_stream_data line unless line.empty?
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
  end
end
