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
  let(:queue) { instance_double 'Queue' }

  it 'prints stream data' do
    expect(Lightstreamer::Session).to receive(:new)
      .with(server_url: 'http://a.com', username: 'username', password: 'password', adapter_set: 'adapter-set')
      .and_return(session)

    expect(Lightstreamer::Subscription).to receive(:new)
      .with(items: ['item'], fields: ['field'], mode: :merge, adapter: 'adapter', maximum_update_frequency: nil,
            selector: nil)
      .and_return(subscription)

    expect(subscription).to receive(:on_data)
    expect(subscription).to receive(:on_overflow)

    expect(session).to receive(:connect)
    expect(session).to receive(:subscribe).with(subscription)
    expect(session).to receive(:error).twice.and_return(Lightstreamer::Errors::SessionEndError.new(31))

    expect(Queue).to receive(:new).and_return(queue)
    expect(queue).to receive(:empty?).and_return(false)
    expect(queue).to receive(:pop).once.and_return('Test')

    expect { cli.stream }.to output("Test\n").to_stdout.and raise_error(Lightstreamer::Errors::SessionEndError)
  end

  it 'formats new data correctly' do
    cli.instance_variable_set :@queue, queue
    expect(queue).to receive(:push).with('item - field1: 1, field2: 2')

    cli.send(:on_data, subscription, 'item', {}, field1: '1', field2: '2')
  end

  it 'formats overflow notifcations correctly' do
    cli.instance_variable_set :@queue, queue
    expect(queue).to receive(:push).with('Overflow of size 3 on item item')

    cli.send(:on_overflow, subscription, 'item', 3)
  end
end
