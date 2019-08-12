module Lightstreamer
  # Internal class used by {Session} that manages a long-running Lightstreamer connection and handles incoming streaming
  # data on a separate thread and makes it available for consumption through {#read_line}.
  #
  # @private
  class StreamConnection
    # The session ID returned from the server when this stream connection was initiated.
    #
    # @return [String, nil]
    attr_reader :session_id

    # The control address to use for this stream connection.
    #
    # @return [String, nil]
    attr_reader :control_address

    # If an error occurs on the stream thread that causes the stream to disconnect then the error will be stored in this
    # attribute.
    #
    # @return [LightstreamerError, nil]
    attr_reader :error

    # Establishes a new stream connection using the authentication details from the passed session.
    #
    # @param [Session] session The session to create a stream connection for.
    def initialize(session)
      @session = session
      @queue = Queue.new

      @connect_result_mutex = Mutex.new
      @connect_result_condition_variable = ConditionVariable.new
    end

    # Establishes a new stream connection using the authentication details from the session that was passed to
    # {#initialize}. Raises a {LightstreamerError} subclass on failure.
    def connect
      return if @thread

      @queue.clear

      @connect_result_mutex.synchronize do
        create_stream_thread
        @connect_result_condition_variable.wait @connect_result_mutex
      end

      return unless @error

      @thread = nil
      raise @error
    end

    # Returns whether or not this stream connection is connected.
    #
    # @return [Boolean]
    def connected?
      !@thread.nil?
    end

    # Disconnects this stream connection by shutting down the streaming thread.
    def disconnect
      return unless @thread

      @thread.exit
      @thread.join

      @thread = nil
    end

    # Reads the next line of streaming data. If the streaming thread is alive then this method blocks the calling thread
    # until a line of data is available or the streaming thread terminates for any reason. If the streaming thread is
    # not active then any unconsumed lines will be returned and after that the return value will be `nil`.
    #
    # @return [String, nil]
    def read_line
      return nil if @queue.empty? && @thread.nil?

      @queue.pop
    end

    private

    def create_stream_thread
      @thread = Thread.new do
        Thread.current.abort_on_exception = true

        create_new_stream

        while @loop
          @loop = false
          bind_to_existing_stream
        end

        @thread = nil
        @queue.push nil
      end
    end

    def create_new_stream
      params = build_params LS_op2: 'create', LS_cid: 'mgQkwtwdysogQz2BJ4Ji kOj2Bg', LS_user: @session.username,
                            LS_password: @session.password

      params[:LS_adapter_set] = @session.adapter_set if @session.adapter_set

      url = URI.join(@session.server_url, '/lightstreamer/create_session.txt').to_s
      execute_stream_post_request url, connect_timeout: 15, query: params

      signal_connect_result_ready
    end

    def bind_to_existing_stream
      params = build_params LS_session: @session_id

      url = URI.join(control_address, '/lightstreamer/bind_session.txt').to_s
      execute_stream_post_request url, connect_timeout: 15, query: params
    end

    def build_params(params)
      params[:LS_requested_max_bandwidth] = @session.requested_maximum_bandwidth

      if @session.polling_enabled
        params[:LS_polling] = true
        params[:LS_polling_millis] = 15_000
      end

      params
    end

    def execute_stream_post_request(url, options)
      @header = StreamConnectionHeader.new

      buffer = StreamBuffer.new
      options[:response_block] = ->(data, _, _) { buffer.process data, &method(:process_stream_line) }
      options[:expects] = 200

      Excon.post url, options
    rescue Excon::Error => e
      @error = Errors::ConnectionError.new e.message
    end

    def signal_connect_result_ready
      @connect_result_mutex.synchronize { @connect_result_condition_variable.signal }
    end

    def process_stream_line(line)
      return if /^(PROBE|Preamble:.*)$/.match?(line)

      if @header
        process_header_line line
      else
        process_body_line line
      end
    end

    def process_header_line(line)
      header_incomplete = @header.process_line line

      @session_id = @header['SessionId']

      # Set the control address and ensure it has a schema
      @control_address = @header['ControlAddress'] || @session.server_url
      unless @control_address.start_with? 'http'
        @control_address = "#{URI(@session.server_url).scheme}://#{@control_address}"
      end

      @error = @header.error

      return if header_incomplete

      @header = nil

      signal_connect_result_ready
    end

    def process_body_line(line)
      if /^LOOP( \d+|)$/.match?(line)
        @loop = true
      elsif /^END( \d+|)$/.match?(line)
        @error = Errors::SessionEndError.new line[4..-1]
      elsif !line.empty?
        @queue.push line
      end
    end
  end
end
