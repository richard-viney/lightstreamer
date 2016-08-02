describe Lightstreamer::SubscriptionItemData do
  let(:item_data) { Lightstreamer::SubscriptionItemData.new }

  it 'sets new data when in command mode' do
    item_data.set_data [], :command
    expect(item_data.data).to eq([])

    item_data.set_data [{ key: '1' }, { key: '2' }], :command
    expect(item_data.data).to eq([{ key: '1' }, { key: '2' }])
  end

  it 'validates new command mode data' do
    expect { item_data.set_data nil, :command }.to raise_error(ArgumentError)
    expect { item_data.set_data [{ value: '1' }], :command }.to raise_error(ArgumentError)
    expect { item_data.set_data [{ key: '1' }, { key: '1' }], :command }.to raise_error(ArgumentError)
  end

  it 'sets new data when in merge mode' do
    item_data.set_data({}, :merge)
    expect(item_data.data).to eq({})

    item_data.set_data({ value: '5' }, :merge)
    expect(item_data.data).to eq(value: '5')
  end

  it 'validates new merge mode data' do
    expect { item_data.set_data nil, :merge }.to raise_error(ArgumentError)
    expect { item_data.set_data [], :merge }.to raise_error(ArgumentError)
  end

  it 'fails setting data for distinct and raw modes' do
    expect { item_data.set_data({}, :distinct) }.to raise_error(ArgumentError)
    expect { item_data.set_data({}, :raw) }.to raise_error(ArgumentError)
  end

  it 'processes new command data' do
    item_data.process_new_command_data command: 'ADD', key: '1', value: 'a'
    expect(item_data.data).to eq([{ key: '1', value: 'a' }])

    item_data.process_new_command_data command: 'UPDATE', key: '1', value: 'b'
    expect(item_data.data).to eq([{ key: '1', value: 'b' }])

    item_data.process_new_command_data command: 'UPDATE', key: '2', value: 'c'
    expect(item_data.data).to eq([{ key: '1', value: 'b' }, { key: '2', value: 'c' }])

    item_data.process_new_command_data command: 'ADD', key: '2', value: 'b'
    expect(item_data.data).to eq([{ key: '1', value: 'b' }, { key: '2', value: 'b' }])

    item_data.process_new_command_data command: 'DELETE', key: '3'
    expect(item_data.data).to eq([{ key: '1', value: 'b' }, { key: '2', value: 'b' }])

    item_data.process_new_command_data command: 'DELETE', key: '1'
    expect(item_data.data).to eq([{ key: '2', value: 'b' }])

    item_data.process_new_command_data command: 'DELETE', key: '5'
    expect(item_data.data).to eq([{ key: '2', value: 'b' }])

    expect { item_data.process_new_command_data command: 'ADD' }.to raise_error(ArgumentError)
  end

  it 'processes new distinct data' do
    item_data.process_new_distinct_data value: 'a'
    expect(item_data.data).to eq(value: 'a')

    item_data.process_new_distinct_data value: 'b'
    expect(item_data.data).to eq(value: 'b')
  end

  it 'processes new merge data' do
    item_data.process_new_merge_data value: 'a'
    expect(item_data.data).to eq(value: 'a')

    item_data.process_new_merge_data value: 'b', name: 'c'
    expect(item_data.data).to eq(value: 'b', name: 'c')

    item_data.process_new_merge_data name: nil
    expect(item_data.data).to eq(value: 'b', name: nil)
  end

  it 'processes new raw data' do
    item_data.process_new_raw_data value: 'a'
    expect(item_data.data).to eq(value: 'a')

    item_data.process_new_raw_data value: 'b'
    expect(item_data.data).to eq(value: 'b')
  end
end
