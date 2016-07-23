describe Lightstreamer::UTF16 do
  it 'decodes UTF-16 escape sequences' do
    tests = {
      # Simple codepoint
      '\u0040' => '@',

      # Two codepoints separated by a backslash
      '\u0040\\\u0041' => '@\A',

      # Two surrogate codepoints surrounded by two normal codepoints
      '\u0042\uD834\uDD1E\u0045' => "B#{[0x1D11E].pack 'U'}E",

      # Invalid codepoint
      '\uEF00' => ''
    }

    tests.each do |input, output|
      expect(Lightstreamer::UTF16.decode_escape_sequences(input)).to eq(output)
    end
  end
end
