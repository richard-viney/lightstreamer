describe Lightstreamer::UpdateMessage do
  let(:items) { [:item1, :item2, :item3] }
  let(:fields) { [:field1, :field2, :field3] }

  it 'parses valid update messages' do
    {
      '18,1|||' => { item_index: 0, values: {} },
      '18,3|#|$|' => { item_index: 2, values: { field1: nil, field2: '' } },

      # Simple UTF-16 codepoint
      '18,1|||\u0040' => { item_index: 0, values: { field3: '@' } },

      # Two codepoints separated by a backslash
      '18,1|||\u0040\\\u0041' => { item_index: 0, values: { field3: '@\A' } },

      # Two surrogate codepoints surrounded by two normal codepoints
      '18,1|||\u0042\uD834\uDD1E\u0045' => { item_index: 0, values: { field3: "B#{[0x1D11E].pack 'U'}E" } },

      # Invalid codepoint
      '18,1|||\uEF00' => { item_index: 0, values: { field3: '' } }
    }.each do |line, result|
      message = Lightstreamer::UpdateMessage.parse line, 18, items, fields

      expect(message).to_not be nil
      expect(message.item_index).to eq(result[:item_index])
      expect(message.values).to eq(result[:values])
    end
  end

  it 'rejects invalid update messages' do
    [
      '',
      '1,1||',
      '18,2|'
    ].each do |line|
      expect(Lightstreamer::UpdateMessage.parse(line, 18, items, fields)).to be nil
    end
  end
end
