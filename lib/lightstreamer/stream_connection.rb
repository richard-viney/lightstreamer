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

    # The control address returned from the server when this stream connection was initiated.
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

      @stream_create_url = URI.join(session.server_url, '/lightstreamer/create_session.txt').to_s
      @stream_bind_url = URI.join(session.server_url, '/lightstreamer/bind_session.txt').to_s

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
    # until a line of data is available. If the streaming thread is not active then any unconsumed lines will be
    # returned and after that the return value will be `nil`.
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

        connect_stream_and_process_data stream_create_post_request

        while @loop
          @loop = false
          connect_stream_and_process_data stream_bind_post_request
        end

        @thread = nil
        @queue.push nil
      end
    end

    def stream_create_post_request
      params = { LS_op2: 'create', LS_cid: 'mgQkwtwdysogQz2BJ4Ji kOj2Bg', LS_user: @session.username,
                 LS_password: @session.password }

      params[:LS_adapter_set] = @session.adapter_set if @session.adapter_set

      Typhoeus::Request.new @stream_create_url, method: :post, connecttimeout: 15, params: params
    end

    def stream_bind_post_request
      Typhoeus::Request.new @stream_bind_url, method: :post, connecttimeout: 15, params: { LS_session: @session_id }
    end

    def connect_stream_and_process_data(request)
      @header = StreamConnectionHeader.new

      buffer = LineBuffer.new
      request.on_body do |data|
        buffer.process data, &method(:process_stream_line)
      end

      request.on_complete(&method(:on_request_complete))
      request.run

      signal_connect_result_ready
    end

    def on_request_complete(response)
      @error = @header.error if @header
      @error = RequestError.new(response.return_message, response.response_code) unless response.success?
    end

    def signal_connect_result_ready
      @connect_result_mutex.synchronize { @connect_result_condition_variable.signal }
    end

    def process_stream_line(line)
      if @header
        process_header_line line
      else
        process_body_line line
      end
    end

    def process_header_line(line)
      return if @header.process_header_line line

      @session_id = @header['SessionId']
      @control_address = @header['ControlAddress']
      @error = @header.error

      signal_connect_result_ready

      @header = nil
    end

    def process_body_line(line)
      if line =~ /^LOOP/
        @loop = true
      elsif line =~ /^END/
        @error = SessionEndError.new line[4..-1]
      elsif line !~ /^(PROBE|Preamble:.*)$/
        @queue.push line
      end
    end
  end
end
