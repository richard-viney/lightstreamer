module Lightstreamer
  # Manages a long-running Lightstreamer connection that handles incoming streaming data on a separate thread and
  # makes it available for consumption via the {#read_line} method.
  class StreamConnection
    # @return [Thread] The thread used to process incoming streaming data.
    attr_reader :thread

    # @return [String] The session ID returned from the server when this stream connection was initiated.
    attr_reader :session_id

    # @return [String] The control address returned from the server when this stream connection was initiated.
    attr_reader :control_address

    # @return [Error] If an error occurs on the stream thread that causes the stream to disconnect then the
    #         error will be stored in this attribute.
    attr_reader :error

    # Establishes a new stream connection using the authentication details from the passed session.
    #
    # @param [Session] session The session to create a stream connection for.
    def initialize(session)
      @session = session
      @queue = Queue.new

      @stream_create_url = URI.join(session.server_url, '/lightstreamer/create_session.txt').to_s
      @stream_bind_url = URI.join(session.server_url, '/lightstreamer/bind_session.txt').to_s
    end

    # Establishes a new stream connection using the authentication details from the session that was passed to
    # {#initialize}. Raises an {Error} subclass on failure.
    def connect
      return if @thread
      @session_id = @error = nil

      create_stream_thread

      # Wait until the connection result is known
      until @session_id || @error
      end

      raise @error if @error
    end

    # Returns whether or not this stream connection is connected.
    #
    # @return [Boolean]
    def connected?
      !@thread.nil?
    end

    # Disconnects this stream connection by shutting down the streaming thread.
    def disconnect
      if @thread
        @thread.exit
        @thread.join
      end

      @session_id = @control_address = @error = @thread = nil
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
      end
    end

    def stream_create_post_request
      params = { LS_op2: 'create', LS_cid: 'mgQkwtwdysogQz2BJ4Ji kOj2Bg', LS_user: @session.username,
                 LS_password: @session.password }

      params[:LS_adapter_set] = @session.adapter_set if @session.adapter_set

      Typhoeus::Request.new @stream_create_url, method: :post, params: params
    end

    def stream_bind_post_request
      Typhoeus::Request.new @stream_bind_url, method: :post, params: { LS_session: @session_id }
    end

    def connect_stream_and_process_data(request)
      @header = StreamConnectionHeader.new

      buffer = LineBuffer.new
      request.on_body do |data|
        buffer.process data, &method(:process_stream_line)
      end

      request.on_complete do |response|
        @error = @header.error if @header
        @error = RequestError.new(response.return_message, response.response_code) unless response.success?
      end

      request.run
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

      @control_address = @header['ControlAddress']
      @session_id = @header['SessionId']

      @header = nil
    end

    def process_body_line(line)
      if line == 'LOOP'
        @loop = true
      elsif line =~ /^END/
        @error = SessionEndError.new line[4..-1]
      elsif !ignore_line?(line)
        @queue.push line
      end
    end

    def ignore_line?(line)
      line =~ /^(PROBE|Preamble:.*)$/
    end
  end
end
