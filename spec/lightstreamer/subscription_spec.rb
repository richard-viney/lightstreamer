describe Lightstreamer::Subscription do
  let(:subscription) { build :subscription, items: [:item1, :item2], fields: [:field1, :field2] }

  it 'assigns unique ids to subscriptions' do
    initial_id = build(:subscription).id

    expect(build(:subscription).id).to eq(initial_id + 1)
    expect(build(:subscription).id).to eq(initial_id + 2)
  end

  it 'turns items and fields into arrays' do
    expect(subscription.items).to eq([:item1, :item2])
    expect(subscription.fields).to eq([:field1, :field2])
  end

  it 'turns mode into a symbol' do
    expect(build(:subscription, mode: 'distinct').mode).to eq(:distinct)
  end

  it 'turns mode into a symbol' do
    expect(build(:subscription, mode: 'distinct').mode).to eq(:distinct)
  end

  it 'raises an exception on unknown items' do
    expect { subscription.item_data :item3 }.to raise_error(ArgumentError)
  end

  it 'invokes callbacks when new data arrives' do
    data_calls = []
    overflow_calls = []

    subscription.on_data { |*args| data_calls << args }
    subscription.on_data { |*args| data_calls << args }
    subscription.on_overflow { |*args| overflow_calls << args }

    expect(subscription.process_stream_data("#{subscription.id},1|a|b")).to be true
    expect(subscription.process_stream_data("#{subscription.id},2|c|")).to be true
    expect(subscription.process_stream_data("#{subscription.id},2,OV5")).to be true
    expect(subscription.process_stream_data("#{subscription.id},1,OV123")).to be true
    expect(subscription.process_stream_data("#{subscription.id},3,OV1")).to be_falsey
    expect(subscription.process_stream_data('0,3|d|e')).to be_falsey

    expect(data_calls.count).to eq(4)
    expect(data_calls[0]).to eq([subscription, :item1, { field1: 'a', field2: 'b' }, { field1: 'a', field2: 'b' }])
    expect(data_calls[1]).to eq([subscription, :item1, { field1: 'a', field2: 'b' }, { field1: 'a', field2: 'b' }])
    expect(data_calls[2]).to eq([subscription, :item2, { field1: 'c' }, { field1: 'c' }])
    expect(data_calls[3]).to eq([subscription, :item2, { field1: 'c' }, { field1: 'c' }])

    expect(overflow_calls.count).to eq(2)
    expect(overflow_calls[0]).to eq([subscription, :item2, 5])
    expect(overflow_calls[1]).to eq([subscription, :item1, 123])
  end

  it 'clears callbacks' do
    call_count = 0

    subscription.on_data { call_count += 1 }
    subscription.on_overflow { call_count += 1 }

    subscription.clear_callbacks

    expect(subscription.process_stream_data("#{subscription.id},1|a|b")).to be true
    expect(subscription.process_stream_data("#{subscription.id},2,OV5")).to be true

    expect(call_count).to eq(0)
  end

  it 'processes stream data' do
    id = subscription.id

    [
      { line: '', item1: {}, item2: {} },
      { line: "#{id},1|a|b", item1: { field1: 'a', field2: 'b' }, item2: {} },
      { line: "#{id},2|$|$", item1: { field1: 'a', field2: 'b' }, item2: { field1: '', field2: '' } },
      { line: "#{id},2|c|d", item1: { field1: 'a', field2: 'b' }, item2: { field1: 'c', field2: 'd' } },
      { line: "#{id},1|e|#", item1: { field1: 'e', field2: nil }, item2: { field1: 'c', field2: 'd' } },
      { line: "#{id},1|$$|##", item1: { field1: '$', field2: '#' }, item2: { field1: 'c', field2: 'd' } },
      { line: "#{id},2||", item1: { field1: '$', field2: '#' }, item2: { field1: 'c', field2: 'd' } },
      { line: "#{id},1|\\u0040|", item1: { field1: '@', field2: '#' }, item2: { field1: 'c', field2: 'd' } }
    ].each do |hash|
      subscription.process_stream_data hash[:line]

      expect(subscription.item_data(:item1)).to eq(hash[:item1])
      expect(subscription.item_data(:item2)).to eq(hash[:item2])
    end

    subscription.clear_data

    expect(subscription.item_data(:item1)).to eq({})
    expect(subscription.item_data(:item2)).to eq({})
  end
end
