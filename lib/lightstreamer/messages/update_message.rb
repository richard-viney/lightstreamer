module Lightstreamer
  # Helper class used by {Subscription} in order to parse incoming update messages.
  #
  # @private
  class UpdateMessage
    # The index of the item this update message applies to.
    #
    # @return [Fixnum]
    attr_accessor :item_index

    # The field values specified by this update message.
    #
    # @return [Array]
    attr_accessor :values

    class << self
      # Attempts to parses the specified line as an update message for the given table, items, and fields, and returns
      # an instance of {UpdateMessage} on success, or `nil` on failure.
      def parse(line, table_id, items, fields)
        message = new

        match = line.match table_regexp(table_id, fields)
        return unless match

        message.item_index = match.captures[0].to_i - 1
        return unless message.item_index < items.size

        message.values = parse_values match.captures[1..-1], fields

        message
      end

      private

      def table_regexp(table_id, fields)
        Regexp.new "^#{table_id},(\\d+)#{'\|(.*)' * fields.size}$"
      end

      def parse_values(values, fields)
        hash = {}

        values.each_with_index do |value, index|
          next if value == ''

          hash[fields[index]] = parse_raw_field_value value
        end

        hash
      end

      def parse_raw_field_value(value)
        return '' if value == '$'
        return nil if value == '#'

        value = value[1..-1] if value =~ /^(\$|#)/

        decode_escape_sequences value
      end

      # Decodes any UTF-16 escape sequences in the form '\uXXXX' in the passed string. Invalid escape sequences are
      # removed.
      def decode_escape_sequences(string)
        string = decode_surrogate_pair_escape_sequences string

        string.gsub(/\\u[A-F\d]{4}/i) do |escape_sequence|
          codepoint = escape_sequence[2..-1].hex

          # Codepoints greater than 0xD7FF are invalid and so are removed
          codepoint < 0xD800 ? [codepoint].pack('U') : ''
        end
      end

      # Decodes any UTF-16 surrogate pair escape sequences in the form '\uXXXX\uYYYY' in the passed string.
      def decode_surrogate_pair_escape_sequences(string)
        string.gsub(/\\uD[89AB][A-F\d]{2}\\uD[C-F][A-F\d]{2}/i) do |escape_sequence|
          high_surrogate = escape_sequence[2...6].hex
          low_surrogate = escape_sequence[8...12].hex

          codepoint = 0x10000 + ((high_surrogate - 0xD800) << 10) + (low_surrogate - 0xDC00)

          [codepoint].pack 'U'
        end
      end
    end
  end
end
