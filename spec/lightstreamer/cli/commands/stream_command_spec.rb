describe Lightstreamer::CLI::Main do
  class ExitLoopError < StandardError
  end

  let(:arguments) do
    { server_url: 'http://a.com', username: 'username', password: 'password', adapter_set: 'adapter-set',
      adapter: 'adapter', items: ['item'], fields: ['field'], mode: :merge }
  end

  let(:cli) { Lightstreamer::CLI::Main.new [], arguments }

  let(:session) { instance_double 'Lightstreamer::Session' }
  let(:subscription) { instance_double 'Lightstreamer::Subscription' }
  let(:queue) { Queue.new }

  it 'prints stream data' do
    expect(Lightstreamer::Session).to receive(:new)
      .with(server_url: 'http://a.com', username: 'username', password: 'password', adapter_set: 'adapter-set')
      .and_return(session)

    expect(session).to receive(:connect)

    expect(Lightstreamer::Subscription).to receive(:new)
      .with(items: ['item'], fields: ['field'], mode: :merge, adapter: 'adapter')
      .and_return(subscription)

    expect(subscription).to receive(:add_data_callback)
    expect(session).to receive(:subscribe).with(subscription)

    expect(Queue).to receive(:new).and_return(queue)
    expect(queue).to receive(:pop).and_return('Test')
    expect(queue).to receive(:pop).and_raise(ExitLoopError)

    expect { cli.stream }.to output("Test\n").to_stdout.and raise_error(ExitLoopError)
  end

  it 'formats new data correctly' do
    cli.instance_variable_set :@queue, queue
    expect(queue).to receive(:push).with('item - field1: 1, field2: 2')

    cli.send(:subscription_data_callback, subscription, 'item', {}, field1: '1', field2: '2')
  end
end
