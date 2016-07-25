describe Lightstreamer::Session do
  let(:session) do
    Lightstreamer::Session.new server_url: 'http://test.com', username: 'username', password: 'password',
                               adapter_set: 'adapter-set'
  end

  let(:stream_connection) { instance_double 'Lightstreamer::StreamConnection' }
  let(:control_connection) { instance_double 'Lightstreamer::ControlConnection' }

  let(:subscription) { build :subscription, items: ['item'], fields: ['field'] }

  context 'that can connect' do
    before do
      expect(Lightstreamer::StreamConnection).to receive(:new).with(session).and_return(stream_connection)
      expect(stream_connection).to receive(:connect)
      expect(stream_connection).to receive(:control_address).and_return('test2.com')
      expect(stream_connection).to receive(:session_id).and_return('session')
    end

    def join_processing_thread(session)
      thread = session.instance_variable_get :@processing_thread
      thread.join if thread
    end

    it 'connects to a stream and processes its data' do
      expect(Lightstreamer::ControlConnection).to receive(:new)
        .with('session', 'http://test2.com')
        .and_return(control_connection)

      expect(stream_connection).to receive(:read_line).and_return("#{subscription.id},1|test")
      expect(stream_connection).to receive(:read_line).and_return('invalid data')
      expect(stream_connection).to receive(:read_line) { Thread.exit }
      expect(stream_connection).to receive(:disconnect)

      session.instance_variable_set :@subscriptions, [subscription]
      expect(subscription).to receive(:process_stream_data).with("#{subscription.id},1|test").and_return(true)
      expect(subscription).to receive(:process_stream_data).with('invalid data').and_return(false)

      expect do
        session.connect
        join_processing_thread session
        session.disconnect
      end.to output("Lightstreamer: unprocessed stream data 'invalid data'\n").to_stderr
    end

    it 'handles when the stream connection dies' do
      expect(stream_connection).to receive(:read_line).and_return(nil)
      expect(stream_connection).to receive(:error).and_return('test')

      expect do
        session.connect
        expect(session.connected?).to be true
        join_processing_thread session
        expect(session.connected?).to be false
        session.disconnect
      end.to output("Lightstreamer: processing thread exiting, error: test\n").to_stderr
    end
  end

  it 'handles when the stream connection fails to connect' do
    expect(Lightstreamer::StreamConnection).to receive(:new).with(session).and_return(stream_connection)
    expect(stream_connection).to receive(:connect).and_raise(Lightstreamer::ProtocolError.new('Error message', 10))

    expect { session.connect }.to raise_error do |error|
      expect(error).to be_a(Lightstreamer::ProtocolError)
      expect(error.error).to eq('Error message')
      expect(error.code).to eq(10)
    end
  end

  it 'subscribes to new subscriptions' do
    session.instance_variable_set :@control_connection, control_connection

    expect(subscription).to receive(:clear_data)
    expect(control_connection).to receive(:execute).with(table: subscription.id, operation: :add, mode: :merge,
                                                         items: subscription.items, fields: subscription.fields,
                                                         adapter: subscription.adapter, maximum_update_frequency: 0.0)

    session.subscribe subscription

    expect(session.subscribed?(subscription)).to be true
  end

  it 'handles a subscription request failing' do
    session.instance_variable_set :@control_connection, control_connection

    expect(subscription).to receive(:clear_data)
    expect(control_connection).to receive(:execute).with(table: subscription.id, operation: :add, mode: :merge,
                                                         items: subscription.items, fields: subscription.fields,
                                                         adapter: subscription.adapter,
                                                         maximum_update_frequency: 0.0).and_raise('test')

    expect { session.subscribe subscription }.to raise_error('test')

    expect(session.subscribed?(subscription)).to be false
  end

  it 'unsubscribes an existing subscription' do
    session.instance_variable_set :@control_connection, control_connection
    session.instance_variable_set :@subscriptions, [subscription]

    expect(control_connection).to receive(:execute).with(table: subscription.id, operation: :delete)

    session.unsubscribe subscription

    expect(session.subscribed?(subscription)).to be false
  end

  it 'handles a subscription unsubscribe for an unknown subscription' do
    expect { session.unsubscribe subscription }.to raise_error(ArgumentError)
  end

  it 'handles a subscription unsubscribe request failing' do
    session.instance_variable_set :@control_connection, control_connection
    session.instance_variable_set :@subscriptions, [subscription]

    expect(control_connection).to receive(:execute).with(table: subscription.id, operation: :delete).and_raise('test')

    expect { session.unsubscribe subscription }.to raise_error('test')

    expect(session.subscribed?(subscription)).to be true
  end
end
