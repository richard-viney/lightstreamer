describe Lightstreamer::CLI::Main do
  let(:cli) do
    Lightstreamer::CLI::Main.new [], server_url: 'http://a.com', username: 'username', password: 'password',
                                     adapter_set: 'adapter-set', requested_maximum_bandwidth: nil,
                                     data_adapter: 'adapter', items: ['item'], fields: ['field'], mode: :merge,
                                     polling_enabled: false
  end

  let(:session) { instance_double 'Lightstreamer::Session' }
  let(:subscription) { instance_double 'Lightstreamer::Subscription' }
  let(:queue) { Queue.new }

  it 'prints stream data' do
    expect(Lightstreamer::Session).to receive(:new)
      .with(server_url: 'http://a.com', username: 'username', password: 'password', adapter_set: 'adapter-set',
            requested_maximum_bandwidth: nil, polling_enabled: false)
      .and_return(session)

    expect(session).to receive(:on_message_result)
    expect(session).to receive(:on_error)
    expect(session).to receive(:connect)
    expect(session).to receive(:session_id).and_return('A')
    expect(session).to receive(:build_subscription)
      .with(items: ['item'], fields: ['field'], mode: :merge, data_adapter: 'adapter', maximum_update_frequency: nil,
            selector: nil, snapshot: nil)
      .and_return(subscription)

    expect(subscription).to receive(:on_data)
    expect(subscription).to receive(:on_overflow)
    expect(subscription).to receive(:on_end_of_snapshot)
    expect(subscription).to receive(:start)

    queue.push 'Test'
    queue.push Lightstreamer::Errors::SessionEndError.new(31)
    expect(Queue).to receive(:new).and_return(queue)

    expect do
      cli.stream
    end.to output("Session ID: A\nTest\nError: Lightstreamer::Errors::SessionEndError\n").to_stdout
  end

  it 'formats new data correctly' do
    cli.instance_variable_set :@queue, queue
    expect(queue).to receive(:push).with('item - field1: 1, field2: 2')

    cli.send :on_data, subscription, 'item', {}, field1: '1', field2: '2'
  end

  it 'formats overflow notifications correctly' do
    cli.instance_variable_set :@queue, queue
    expect(queue).to receive(:push).with('Overflow of size 3 on item item')

    cli.send :on_overflow, subscription, 'item', 3
  end

  it 'formats message outcomes correctly' do
    cli.instance_variable_set :@queue, queue
    expect(queue).to receive(:push).with('Message result for name[1] = Done')
    expect(queue).to receive(:push).with('Message result for name[2, 3] = Lightstreamer::Errors::IllegalMessageError')

    cli.send :on_message_result, 'name', [1], nil
    cli.send :on_message_result, 'name', [2, 3], Lightstreamer::Errors::IllegalMessageError.new
  end

  it 'formats end-of-snapshot notifications correctly' do
    cli.instance_variable_set :@queue, queue
    expect(queue).to receive(:push).with('End of snapshot for item item')

    cli.send :on_end_of_snapshot, subscription, 'item'
  end

  it 'puts errors on the queue' do
    sync_error = Lightstreamer::Errors::SyncError.new

    cli.instance_variable_set :@queue, queue
    expect(queue).to receive(:push).with(sync_error)

    cli.send :on_error, sync_error
  end
end
