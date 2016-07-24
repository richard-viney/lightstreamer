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

    # Establishes a new stream connection using the authentication details from the passed session.
    #
    # @param [Session] session The session to create a stream connection for.
    def initialize(session)
      @session = session
      @queue = Queue.new

      @stream_create_uri = URI.join session.server_url, '/lightstreamer/create_session.txt'
      @stream_bind_uri = URI.join session.server_url, '/lightstreamer/bind_session.txt'
    end

    # Establishes a new stream connection using the authentication details from the session that was passed to
    # {#initialize}. Raises {ProtocolError} or {RequestError} on failure.
    def connect
      return if @thread
      @session_id = @connection_error = nil

      create_stream_thread

      # Wait until the connection result is known
      until @session_id || @connection_error
      end

      raise @connection_error if @connection_error
    end

    # Disconnects this stream connection by shutting down the streaming thread.
    def disconnect
      return unless @thread

      Thread.kill @thread
      @thread.join

      @session_id = @control_address = @connection_error = @thread = nil
    end

    # Reads the next line of streaming data. This method blocks the calling thread until a line of data is available.
    def read_line
      @queue.pop
    end

    private

    def create_stream_thread
      @thread = Thread.new do
        begin
          stream_thread_main
        rescue StandardError => error
          warn "Lightstreamer: exception in stream thread: #{error}"
          exit 1
        end
      end
    end

    def stream_thread_main
      http = Net::HTTP.new @stream_create_uri.host, @stream_create_uri.port
      http.use_ssl = true if @stream_create_uri.port == 443

      connect_stream_and_process_data http, stream_create_post_request

      while @loop
        @loop = false
        connect_stream_and_process_data http, stream_bind_post_request
      end
    end

    def stream_create_post_request
      Net::HTTP::Post.new(@stream_create_uri.path).tap do |request|
        params = { LS_op2: 'create', LS_cid: 'mgQkwtwdysogQz2BJ4Ji kOj2Bg', LS_user: @session.username,
                   LS_password: @session.password }

        params[:LS_adapter_set] = @session.adapter_set if @session.adapter_set

        request.body = URI.encode_www_form(params)
      end
    end

    def stream_bind_post_request
      Net::HTTP::Post.new(@stream_bind_uri.path).tap do |request|
        request.body = URI.encode_www_form LS_session: @session_id
      end
    end

    def connect_stream_and_process_data(http, request)
      buffer = LineBuffer.new

      http.request request do |response|
        @header = StreamConnectionHeader.new
        response.read_body do |data|
          buffer.process data, &method(:process_stream_line)
        end
      end
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
      @connection_error = @header.error

      @header = nil
    end

    def process_body_line(line)
      if line == 'LOOP'
        @loop = true
      elsif !ignore_line?(line)
        @queue.push line
      end
    end

    def ignore_line?(line)
      line =~ /^(PROBE|Preamble:.*)$/
    end
  end
end
