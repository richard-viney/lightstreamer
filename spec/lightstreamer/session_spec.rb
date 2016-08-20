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

    on_message_result_callback = instance_double 'Proc'
    expect(on_message_result_callback).to receive(:call).with('sequence', [5], nil)
    session.on_message_result { |*args| on_message_result_callback.call(*args) }

    recurring_line = "#{subscription.id},1|test"

    expect(session).to receive(:control_request).with(LS_op: :destroy) { recurring_line = nil }

    expect(stream_connection).to receive(:read_line).and_return("#{subscription.id},1|test")
    expect(stream_connection).to receive(:read_line).and_return('invalid data')
    expect(stream_connection).to receive(:read_line).and_return('MSG,sequence,5,DONE')
    allow(stream_connection).to receive(:read_line) { recurring_line }

    session.instance_variable_set :@subscriptions, [subscription]
    expect(subscription).to receive(:process_stream_data).with("#{subscription.id},1|test").and_return(true)
    expect(subscription).to receive(:process_stream_data).with('invalid data').and_return(false)
    expect(subscription).to receive(:process_stream_data).with('MSG,sequence,5,DONE').and_return(false)
    allow(subscription).to receive(:process_stream_data).with("#{subscription.id},1|test").and_return(true)

    expect do
      session.connect
      expect(session.session_id).to eq('session')
      session.disconnect
    end.to output("Lightstreamer: unprocessed stream data 'invalid data'\n").to_stderr
  end

  it 'runs error callbacks on a stream connection error' do
    expect(Lightstreamer::StreamConnection).to receive(:new).with(session).and_return(stream_connection)

    expect(stream_connection).to receive(:connect)
    expect(stream_connection).to receive(:read_line).and_return(nil)
    expect(stream_connection).to receive(:error).and_return(Lightstreamer::Errors::SessionEndError.new(31))

    received_error = nil
    session.on_error { |error| received_error = error }

    session.connect

    processing_thread = session.instance_variable_get :@processing_thread
    processing_thread.join if processing_thread

    expect(session.connected?).to be false
    expect(received_error).to be_a(Lightstreamer::Errors::SessionEndError)
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
    expect(session).to receive(:stop_subscriptions).with([subscription]).and_return([nil])
    expect { session.remove_subscription subscription }.to_not raise_error

    expect(session).to receive(:stop_subscriptions)
      .with([subscription])
      .and_return([Lightstreamer::LightstreamerError.new])
    expect { session.remove_subscription subscription }.to raise_error(Lightstreamer::LightstreamerError)
  end

  it 'removes multiple subscriptions' do
    expect(session).to receive(:stop_subscriptions).with([subscription, subscription]).and_return([nil, nil])

    expect(subscription.session).to_not be nil
    session.remove_subscriptions [subscription, subscription]
    expect(subscription.session).to be nil
  end

  context 'with an active stream connection' do
    before do
      session.instance_variable_set :@stream_connection, stream_connection
    end

    it 'rebinds the stream connection' do
      expect(session).to receive(:control_request).with(LS_op: :force_rebind)
      session.force_rebind
    end

    it 'sets the requested maximum bandwidth' do
      expect(session.requested_maximum_bandwidth).to eq(10)
      expect(session).to receive(:control_request).with(LS_op: :constrain, LS_requested_max_bandwidth: 15)
      session.requested_maximum_bandwidth = 15
      expect(session.requested_maximum_bandwidth).to eq(15)
    end

    it 'sends a synchronous message' do
      expect(Lightstreamer::PostRequest).to receive(:execute)
        .with('http://a.com/lightstreamer/send_message.txt', LS_session: 'session', LS_message: 'message')

      session.send_message 'message'
    end

    it 'sends an synchronous message' do
      expect(Lightstreamer::PostRequest).to receive(:execute)
        .with('http://a.com/lightstreamer/send_message.txt', LS_session: 'session', LS_message: 'message',
                                                             LS_sequence: 'sequence', LS_msg_prog: 1, LS_max_wait: 500)

      session.send_message 'message', async: true, sequence: 'sequence', number: 1, max_wait: 500
    end

    it 'sends control requests' do
      expect(Lightstreamer::PostRequest).to receive(:execute)
        .with('http://a.com/lightstreamer/control.txt', LS_session: 'session', LS_op: :operation, test: 1)

      session.control_request LS_op: :operation, test: 1
    end

    it 'starts multiple subscriptions at once' do
      expect(session).to receive(:perform_subscription_actions)
        .with([{ subscription: 1, action: :start, options: { snapshot: true } },
               { subscription: 2, action: :start, options: { snapshot: true } }])
        .and_return([nil, nil])

      expect(session.start_subscriptions([1, 2], snapshot: true)).to eq([nil, nil])
    end

    it 'stops multiple subscriptions at once' do
      expect(session).to receive(:perform_subscription_actions)
        .with([{ subscription: 1, action: :stop }, { subscription: 2, action: :stop }]).and_return([nil, nil])

      expect(session.stop_subscriptions([1, 2])).to eq([nil, nil])
    end

    it 'performs a set of subscription actions' do
      subscriptions = [subscription, build(:subscription, session: session), build(:subscription, session: session)]

      expect(Lightstreamer::PostRequest).to receive(:request_body)
        .with(LS_session: 'session', LS_op: :add, LS_table: subscriptions[0].id, LS_mode: 'MERGE', LS_id: %w(item),
              LS_schema: %w(field), LS_selector: 'selector', LS_data_adapter: nil, LS_requested_max_frequency: 0.0,
              LS_snapshot: false)
        .and_return('body1')

      expect(Lightstreamer::PostRequest).to receive(:request_body)
        .with(LS_session: 'session', LS_op: :start, LS_table: subscriptions[1].id)
        .and_return('body2')

      expect(Lightstreamer::PostRequest).to receive(:request_body)
        .with(LS_session: 'session', LS_op: :delete, LS_table: subscriptions[2].id)
        .and_return('body3')

      expect(Lightstreamer::PostRequest).to receive(:execute_multiple)
        .with('http://a.com/lightstreamer/control.txt', %w(body1 body2 body3))
        .and_return([nil, Lightstreamer::Errors::InvalidDataAdapterError.new, nil])

      errors = session.perform_subscription_actions [{ subscription: subscriptions[0], action: :start },
                                                     { subscription: subscriptions[1], action: :unsilence },
                                                     { subscription: subscriptions[2], action: :stop }]

      expect(errors.size).to eq(3)
      expect(errors[0]).to be nil
      expect(errors[1]).to be_a(Lightstreamer::Errors::InvalidDataAdapterError)
      expect(errors[2]).to be nil

      expect(subscriptions[0].active).to be_truthy
      expect(subscriptions[2].active).to be_falsey
    end
  end
end
