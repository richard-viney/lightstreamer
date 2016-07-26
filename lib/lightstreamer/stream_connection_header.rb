module Lightstreamer
  # Internal class used by {StreamConnection} that processes the contents of the header returned by the server when a
  # new stream connection is created or an existing session is bound to.
  #
  # @private
  class StreamConnectionHeader
    # If there was an error in the header then this value will be set to the error instance that should be raised in
    # response.
    #
    # @return [Error, nil]
    attr_reader :error

    def initialize
      @data = {}
      @lines = []
    end

    # Processes a single line of header information. The return value indicates whether further data is required in
    # order to complete the header.
    #
    # @param [String] line The line of header data to process.
    #
    # @return [Boolean] Whether the header is still incomplete and requires further data.
    def process_header_line(line)
      @lines << line

      return process_success if @lines.first == 'OK'
      return process_error if @lines.first == 'ERROR'
      return process_end if @lines.first == 'END'
      return process_sync_error if @lines.first == 'SYNC ERROR'

      process_unrecognized
    end

    # Returns the value for the item with the specified name in this header, or `nil` if no item with the specified name
    # was part of this header.
    #
    # @param [String] item_name The name of the item to return the header value for.
    #
    # @return [String, nil] The value of the item as specified in this header, or `nil` if the item name was not
    #         specified in this header.
    def [](item_name)
      @data[item_name]
    end

    private

    def process_success
      match = @lines.last.match(/^([^:]*):(.*)$/)
      @data[match.captures[0]] = match.captures[1] if match

      !@lines.last.empty?
    end

    def process_error
      @error = LightstreamerError.build @lines[2], @lines[1]
      true
    end

    def process_end
      @error = SessionEndError.new @lines[1]
      true
    end

    def process_sync_error
      @error = SyncError.new
      false
    end

    def process_unrecognized
      @error = LightstreamerError.new @lines.join(' ')
      true
    end
  end
end
