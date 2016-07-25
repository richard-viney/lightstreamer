module Lightstreamer
  # Helper class that processes the contents of the header returned by the server when a new stream connection is
  # created or an existing session is bound to.
  class StreamConnectionHeader
    # @return [ProtocolError, RequestError] If there was an error in the header then this value will be set to the
    #         error instance that should be raised in response.
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

      unless %w(OK ERROR).include? @lines.first
        @error = RequestError.new line
        return false
      end

      return true unless header_complete?

      parse_header

      false
    end

    # Returns the value for the item with the specified name in this header, or `nil` if no item with the specified name
    # was part of this header
    #
    # @param [String] item_name The name of the item to return the header value for.
    #
    # @return [String, nil] The value of the item as specified in this header, or `nil` if the item name was not
    #         specified in this header.
    def [](item_name)
      @data[item_name]
    end

    private

    def header_complete?
      @lines.first == 'OK' && @lines.last.empty? || @lines.first == 'ERROR' && @lines.size == 3
    end

    def parse_header
      if @lines.first == 'OK'
        @lines[1..-1].each do |line|
          match = line.match(/^([^:]*):(.*)$/)
          @data[match.captures[0]] = match.captures[1] if match
        end
      elsif @lines.first == 'ERROR'
        @error = ProtocolError.new @lines[2], @lines[1]
      end
    end
  end
end
