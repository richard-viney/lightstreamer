module Lightstreamer
  # This module supports the decoding of UTF-16 escape sequences
  module UTF16
    module_function

    # Decodes any UTF-16 escape sequences in the form '\uXXXX' into a new string. Invalid escape sequences are removed.
    def decode_escape_sequences(string)
      string = decode_surrogate_pairs_escape_sequences string

      # Match all remaining escape sequences
      string.gsub(/\\u[A-F\d]{4}/i) do |escape_sequence|
        codepoint = escape_sequence[2..-1].hex

        # Codepoints greater than 0xD7FF are invalid
        codepoint < 0xD800 ? [codepoint].pack('U') : ''
      end
    end

    # Converts any UTF-16 surrogate pairs escape sequences in the form '\uXXXX\uYYYY' into UTF-8.
    def decode_surrogate_pairs_escape_sequences(string)
      string.gsub(/\\uD[89AB][A-F\d]{2}\\uD[C-F][A-F\d]{2}/i) do |escape_sequence|
        high_surrogate = escape_sequence[2...6].hex
        low_surrogate = escape_sequence[8...12].hex

        codepoint = 0x10000 + ((high_surrogate - 0xD800) << 10) + (low_surrogate - 0xDC00)

        [codepoint].pack 'U'
      end
    end
  end
end
