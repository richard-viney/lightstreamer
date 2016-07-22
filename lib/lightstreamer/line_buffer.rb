module Lightstreamer
  # Helper class that takes an incoming stream of ASCII data and yields back individual lines as they become complete.
  class LineBuffer
    def initialize
      @buffer = ''
    end

    # Appends a new piece of ASCII data to this buffer. Any lines that are now complete will be yielded back.
    #
    # @param [String] data The new piece of ASCII data.
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
