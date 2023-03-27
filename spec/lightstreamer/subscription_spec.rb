describe Lightstreamer::Subscription do
  let(:session) { instance_double Lightstreamer::Session, session_id: 'id' }
  let(:subscription) { build(:subscription, session: session, items: %i[item1 item2], fields: %i[field1 field2]) }

  it 'assigns consecutive unique ids to subscriptions' do
    initial_id = build(:subscription).id

    expect(build(:subscription).id).to eq(initial_id + 1)
    expect(build(:subscription).id).to eq(initial_id + 2)
  end

  it 'turns mode into a symbol' do
    expect(build(:subscription, mode: 'distinct').mode).to eq(:distinct)
  end

  it 'raises on unknown items' do
    expect { subscription.item_data :item3 }.to raise_error(ArgumentError)
    expect { subscription.set_item_data :item3, {} }.to raise_error(ArgumentError)
  end

  it 'starts and stops a subscription' do
    expect(session).to receive(:control_request)
      .with({ LS_session: 'id', LS_op: :add, LS_table: subscription.id, LS_mode: 'MERGE', LS_id: %i[item1 item2],
              LS_snapshot: false, LS_schema: %i[field1 field2], LS_data_adapter: nil, LS_requested_max_frequency: 0.0,
              LS_selector: nil })
    expect(session).to receive(:control_request).with({ LS_session: 'id', LS_op: :delete, LS_table: subscription.id })

    expect(subscription.active).to be_falsey
    subscription.start
    expect(subscription.active).to be_truthy
    subscription.stop
    expect(subscription.active).to be_falsey
  end

  it 'starts and unsilences a silent subscription' do
    expect(session).to receive(:control_request)
      .with({ LS_session: 'id', LS_op: :add_silent, LS_table: subscription.id, LS_mode: 'MERGE', LS_id: %i[item1 item2],
              LS_selector: nil, LS_schema: %i[field1 field2], LS_data_adapter: nil, LS_requested_max_frequency: 0.0,
              LS_snapshot: true })
    expect(session).to receive(:control_request).with({ LS_session: 'id', LS_op: :start, LS_table: subscription.id })

    subscription.start silent: true, snapshot: true
    subscription.unsilence
  end

  it 'changes the maximum update frequency' do
    subscription.instance_variable_set :@active, true
    expect(session).to receive(:control_request).with(LS_op: :reconf, LS_table: subscription.id,
                                                      LS_requested_max_frequency: 2)
    subscription.maximum_update_frequency = 2
    expect(subscription.maximum_update_frequency).to eq(2)

    expect(session).to receive(:control_request).with(LS_op: :reconf, LS_table: subscription.id,
                                                      LS_requested_max_frequency: :unfiltered)
    subscription.maximum_update_frequency = 'unfiltered'
    expect(subscription.maximum_update_frequency).to eq(:unfiltered)
  end

  it 'invokes callbacks when new data arrives' do
    data_calls = []
    overflow_calls = []
    end_of_snapshot_calls = []

    subscription.on_data { |*args| data_calls << args }
    subscription.on_data { |*args| data_calls << args }
    subscription.on_overflow { |*args| overflow_calls << args }
    subscription.on_end_of_snapshot { |*args| end_of_snapshot_calls << args }

    expect(subscription.process_stream_data("#{subscription.id},1|a|b")).to be true
    expect(subscription.process_stream_data("#{subscription.id},2|c|")).to be true
    expect(subscription.process_stream_data("#{subscription.id},2,OV5")).to be true
    expect(subscription.process_stream_data("#{subscription.id},1,OV123")).to be true
    expect(subscription.process_stream_data("#{subscription.id},3,OV1")).to be_falsey
    expect(subscription.process_stream_data('0,3|d|e')).to be_falsey
    expect(subscription.process_stream_data("#{subscription.id},1,EOS")).to be true
    expect(subscription.process_stream_data("#{subscription.id},2,EOS")).to be true

    expect(data_calls.count).to eq(4)
    expect(data_calls[0]).to eq([subscription, :item1, { field1: 'a', field2: 'b' }, { field1: 'a', field2: 'b' }])
    expect(data_calls[1]).to eq([subscription, :item1, { field1: 'a', field2: 'b' }, { field1: 'a', field2: 'b' }])
    expect(data_calls[2]).to eq([subscription, :item2, { field1: 'c' }, { field1: 'c' }])
    expect(data_calls[3]).to eq([subscription, :item2, { field1: 'c' }, { field1: 'c' }])

    expect(overflow_calls.count).to eq(2)
    expect(overflow_calls[0]).to eq([subscription, :item2, 5])
    expect(overflow_calls[1]).to eq([subscription, :item1, 123])

    expect(end_of_snapshot_calls[0]).to eq([subscription, :item1])
    expect(end_of_snapshot_calls[1]).to eq([subscription, :item2])
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

  it 'sets merge item data' do
    subscription.set_item_data :item1, test: 1
    expect(subscription.item_data(:item1)).to eq(test: 1)
  end

  it 'sets distinct item data' do
    command_subscription = build(:subscription, session: session, mode: :command, items: [:item1],
                                                fields: %i[key command test])

    command_subscription.set_item_data :item1, [{ key: 1, test: 2 }]
    expect(command_subscription.item_data(:item1)).to eq([{ key: 1, test: 2 }])
  end
end
