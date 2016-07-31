module Lightstreamer
  # Helper class used by {Subscription} in order to parse incoming end-of-snapshot messages.
  #
  # @private
  class EndOfSnapshotMessage
    # The index of the item this end-of-snapshot message applies to.
    #
    # @return [Fixnum]
    attr_accessor :item_index

    class << self
      # Attempts to parses the specified line as an end-of-snapshot message for the given table and items and returns an
      # instance of {EndOfSnapshotMessage} on success, or `nil` on failure.
      def parse(line, table_id, items)
        message = new

        match = line.match Regexp.new("^#{table_id},(\\d+),EOS$")
        return unless match

        message.item_index = match.captures[0].to_i - 1
        return unless message.item_index < items.size

        message
      end
    end
  end
end
