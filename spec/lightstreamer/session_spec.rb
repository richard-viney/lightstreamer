describe Lightstreamer::Session do
  let(:session) do
    Lightstreamer::Session.new server_url: 'http://test.com', username: 'username', password: 'password',
                               adapter_set: 'adapter-set', requested_maximum_bandwidth: 10
  end

  let(:stream_connection) do
    instance_double 'Lightstreamer::StreamConnection', session_id: 'session', control_address: 'http://a.com'
  end

  let(:subscription) { build :subscription, session: session, items: ['item'], fields: ['field'], selector: 'selector' }

  it 'connects to a stream, processes some data, then disconnects' do
    expect(Lightstreamer::StreamConnection).to receive(:new).with(session).and_return(stream_connection)
    expect(stream_connection).to receive(:connect)

    recurring_line = "#{subscription.id},1|test"

    expect(session).to receive(:control_request).with(:destroy) { recurring_line = nil }

    expect(stream_connection).to receive(:read_line).and_return("#{subscription.id},1|test")
    expect(stream_connection).to receive(:read_line).and_return('invalid data')
    allow(stream_connection).to receive(:read_line) { recurring_line }
    expect(stream_connection).to receive(:error).and_return(nil)

    session.instance_variable_set :@subscriptions, [subscription]
    expect(subscription).to receive(:process_stream_data).with("#{subscription.id},1|test").and_return(true)
    expect(subscription).to receive(:process_stream_data).with('invalid data').and_return(false)
    allow(subscription).to receive(:process_stream_data).with("#{subscription.id},1|test").and_return(true)

    expect do
      session.connect
      expect(session.session_id).to eq('session')
      session.disconnect
    end.to output("Lightstreamer: unprocessed stream data 'invalid data'\n").to_stderr
  end

  it 'handles when the stream connection dies' do
    expect(Lightstreamer::StreamConnection).to receive(:new).with(session).and_return(stream_connection)

    expect(stream_connection).to receive(:connect)
    expect(stream_connection).to receive(:read_line).and_return(nil)
    expect(stream_connection).to receive(:error).and_return(Lightstreamer::Errors::SessionEndError.new(31))

    session.connect

    processing_thread = session.instance_variable_get :@processing_thread
    processing_thread.join if processing_thread

    expect(session.connected?).to be false
    expect(session.error).to be_a(Lightstreamer::Errors::SessionEndError)
  end

  it 'handles when the stream connection fails to connect' do
    expect(Lightstreamer::StreamConnection).to receive(:new).with(session).and_return(stream_connection)
    expect(stream_connection).to receive(:connect).and_raise(Lightstreamer::Errors::AuthenticationError)

    expect { session.connect }.to raise_error(Lightstreamer::Errors::AuthenticationError)
  end

  it 'builds a new subscription' do
    expect(Lightstreamer::Subscription).to receive(:new).with(session, {}).and_return(subscription)
    expect(session.build_subscription({})).to eq(subscription)
  end

  it 'removes a subscription' do
    session.instance_variable_set :@subscriptions, [subscription]

    expect(subscription).to receive(:stop)

    session.remove_subscription subscription

    expect { session.remove_subscription subscription }.to raise_error(ArgumentError)
  end

  context 'with an active stream connection' do
    before do
      session.instance_variable_set :@stream_connection, stream_connection
    end

    it 'rebinds the stream connection' do
      expect(session).to receive(:control_request).with(:force_rebind)
      session.force_rebind
    end

    it 'sets the requested maximum bandwidth' do
      expect(session.requested_maximum_bandwidth).to eq(10)
      expect(session).to receive(:control_request).with(:constrain, LS_requested_max_bandwidth: 15)
      session.requested_maximum_bandwidth = 15
      expect(session.requested_maximum_bandwidth).to eq(15)
    end

    it 'sends control requests' do
      expect(Lightstreamer::ControlConnection).to receive(:execute).with('http://a.com', 'session', :operation, test: 1)

      session.control_request :operation, test: 1
    end
  end
end
