describe Lightstreamer::EndOfSnapshotMessage do
  let(:items) { %i[item1 item2 item3 item4 item5 item6 item7 item8 item9 item10] }

  it 'parses valid end-of-snapshot messages' do
    expect(described_class.parse('18,1,EOS', 18, items).item_index).to eq(0)
    expect(described_class.parse('18,10,EOS', 18, items).item_index).to eq(9)
  end

  it 'rejects invalid end-of-snapshot messages' do
    ['', '1,1,EO', '18,20,EOS', '18,10,EOS '].each do |line|
      expect(described_class.parse(line, 18, items)).to be_nil
    end
  end
end
