describe Lightstreamer::OverflowMessage do
  let(:items) { %i[item1 item2 item3 item4 item5 item6 item7 item8 item9 item10] }

  it 'parses valid overflow messages' do
    {
      '18,1,OV5' => { item_index: 0, overflow_size: 5 },
      '18,10,OV999' => { item_index: 9, overflow_size: 999 }
    }.each do |line, result|
      message = described_class.parse line, 18, items

      expect(message).to be_a(described_class)
      expect(message.item_index).to eq(result[:item_index])
      expect(message.overflow_size).to eq(result[:overflow_size])
    end
  end

  it 'rejects invalid overflow messages' do
    [
      '',
      '1,1,OV5',
      '18,20,OV5',
      '18,10,OV999 ABC'
    ].each do |line|
      expect(described_class.parse(line, 18, items)).to be nil
    end
  end
end
