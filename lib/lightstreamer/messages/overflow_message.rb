module Lightstreamer
  # Helper class used by {Subscription} in order to parse incoming overflow messages.
  #
  # @private
  class OverflowMessage
    # The index of the item this overflow message applies to.
    #
    # @return [Fixnum]
    attr_accessor :item_index

    # The size of the overflow that occurred.
    #
    # @return [Fixnum]
    attr_accessor :overflow_size

    class << self
      # Attempts to parses the specified line as an overflow message for the given table and items and returns an
      # instance of {OverflowMessage} on success, or `nil` on failure.
      def parse(line, table_id, items)
        message = new

        match = line.match table_regexp(table_id)
        return unless match

        message.item_index = match.captures[0].to_i - 1
        return unless message.item_index < items.size

        message.overflow_size = match.captures[1].to_i

        message
      end

      private

      def table_regexp(table_id)
        Regexp.new "^#{table_id},(\\d+),OV(\\d+)$"
      end
    end
  end
end
