module Lightstreamer
  # Manages a long-running Lightstreamer connection that handles incoming streaming data on a separate thread and
  # makes it available for consumption via the {#read_line} method.
  class StreamConnection
    # @return [Thread] The thread used to process incoming streaming data.
    attr_reader :thread

    # Establishes a new stream connection using the authentication details from the passed session.
    #
    # @param [Session] session The session to create a stream connection for.
    def initialize(session)
      @session = session
      @queue = Queue.new

      create_stream
      create_stream_thread
    end

    # Disconnects this stream connection by shutting down the streaming thread.
    def disconnect
      return unless @thread

      Thread.kill @thread
      @thread.join
    end

    # Reads the next line of streaming data. This method blocks the calling thread until a line of data is available.
    def read_line
      @queue.pop
    end

    private

    def create_stream
      @stream = Net::HTTP.new stream_uri.host, stream_uri.port
      @stream.use_ssl = true if stream_uri.port == 443
    end

    def create_stream_thread
      @thread = Thread.new do
        begin
          connect_stream_and_queue_data
        rescue StandardError => error
          warn "Lightstreamer: exception in stream thread: #{error}"
          exit 1
        end
      end
    end

    def initiate_stream_post_request
      Net::HTTP::Post.new(stream_uri.path).tap do |request|
        request.body = stream_create_parameters
      end
    end

    def connect_stream_and_queue_data
      @stream.request initiate_stream_post_request do |response|
        buffer = LineBuffer.new
        response.read_body do |data|
          buffer.process data do |line|
            @queue.push line unless ignore_line? line
          end
        end
      end
    end

    def stream_uri
      URI.join @session.server_url, '/lightstreamer/create_session.txt'
    end

    def stream_create_parameters
      params = {
        LS_op2: 'create',
        LS_cid: 'mgQkwtwdysogQz2BJ4Ji kOj2Bg',
        LS_user: @session.username,
        LS_password: @session.password
      }

      params[:LS_adapter_set] = @session.adapter_set if @session.adapter_set

      URI.encode_www_form params
    end

    def ignore_line?(line)
      line =~ /^(PROBE|Preamble:.*)$/
    end
  end
end
