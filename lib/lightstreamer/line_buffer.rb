module Lightstreamer
  # Helper class used by {StreamConnection} that takes an incoming stream of ASCII data and yields back individual lines
  # as they become complete.
  #
  # @private
  class LineBuffer
    def initialize
      @buffer = ''
    end

    # Appends a new piece of ASCII data to this buffer and yields back any lines that are now complete.
    #
    # @param [String] data The new piece of ASCII data.
    #
    # @yieldparam [String] line The new line that is now complete.
    def process(data)
      @buffer << data

      lines = @buffer.split "\n"
      @buffer = @buffer.end_with?("\n") ? '' : lines.pop

      lines.each do |line|
        yield line.strip
      end
    end
  end
end
