describe Lightstreamer::StreamConnection do
  let(:session) do
    Lightstreamer::Session.new server_url: 'http://test.com', username: 'username', password: 'password',
                               adapter_set: 'set', polling_enabled: false, requested_maximum_bandwidth: 2.5
  end

  let(:url) { 'http://test.com/lightstreamer/create_session.txt' }

  let(:create_args) do
    query = { LS_op2: 'create', LS_cid: 'mgQkwtwdysogQz2BJ4Ji kOj2Bg', LS_user: 'username', LS_password: 'password',
              LS_adapter_set: 'set', LS_requested_max_bandwidth: 2.5 }

    [url, hash_including(query: query, connect_timeout: 15)]
  end

  it 'creates and runs a stream connection with a simple lifecycle' do
    expect(Excon).to receive(:post).with(*create_args) do |_url, params|
      params[:response_block].call "OK\r\nSessionId:A\r\n\r\none\r\ntwo\r\n", nil, nil
      loop { params[:response_block].call "one\r\ntwo\r\n", nil, nil }
    end

    stream_connection = described_class.new session
    stream_connection.connect

    expect(stream_connection.connected?).to be true
    expect(stream_connection.session_id).to eq('A')
    expect(stream_connection.control_address).to eq('http://test.com')

    expect(stream_connection.read_line).to eq('one')
    expect(stream_connection.read_line).to eq('two')

    stream_connection.disconnect

    expect(stream_connection.connected?).to be false
  end

  it 'creates and runs a polling connection which rebinds in response to a LOOP message' do
    session.polling_enabled = true

    stream_thread = nil

    shared_query_params = { LS_requested_max_bandwidth: 2.5, LS_polling: true, LS_polling_millis: 15_000 }
    create_query_params = { LS_op2: 'create', LS_cid: 'mgQkwtwdysogQz2BJ4Ji kOj2Bg', LS_user: 'username',
                            LS_password: 'password', LS_adapter_set: 'set' }.merge shared_query_params

    expect(Excon).to receive(:post)
      .with(url, hash_including(query: create_query_params, connect_timeout: 15)) do |_url, params|
      stream_thread = Thread.current
      params[:response_block].call "OK\r\nSessionId:A\r\nControlAddress:a.com\r\n\r\none\r\ntwo\r\nLOOP\r\n", nil, nil
    end

    bind_args = ['http://a.com/lightstreamer/bind_session.txt',
                 hash_including(query: { LS_session: 'A' }.merge(shared_query_params), connect_timeout: 15)]
    expect(Excon).to receive(:post).with(*bind_args) do |_url, params|
      params[:response_block].call "OK\r\nSessionId:A\r\nControlAddress:a.com\r\n\r\nthree\r\nfour\r\n", nil, nil
      sleep
    end

    stream_connection = described_class.new session
    stream_connection.connect

    expect(stream_connection.connected?).to be true
    expect(stream_connection.control_address).to eq('http://a.com')

    expect(stream_connection.read_line).to eq('one')
    expect(stream_connection.read_line).to eq('two')
    expect(stream_connection.read_line).to eq('three')
    expect(stream_connection.read_line).to eq('four')

    stream_thread.run

    loop { break unless stream_connection.connected? }
  end

  it 'handles a stream connection which is terminated by the server' do
    stream_thread = nil

    expect(Excon).to receive(:post).with(*create_args) do |_url, params|
      stream_thread = Thread.current
      params[:response_block].call "OK\r\nSessionId:A\r\n\r\n", nil, nil
      sleep
      params[:response_block].call "one\r\ntwo\r\nEND\r\nthree\r\n", nil, nil
    end

    stream_connection = described_class.new session
    stream_connection.connect

    stream_thread.run

    expect(stream_connection.read_line).to eq('one')
    expect(stream_connection.read_line).to eq('two')
    expect(stream_connection.read_line).to eq('three')
    expect(stream_connection.error).to be_a(Lightstreamer::Errors::SessionEndError)

    loop { break unless stream_connection.connected? }
  end

  it 'handles an HTTP error on the stream thread' do
    expect(Excon).to receive(:post).and_raise(Excon::Error.new('message'))

    expect { described_class.new(session).connect }.to raise_error do |error|
      expect(error).to be_a(Lightstreamer::Errors::ConnectionError)
      expect(error.message).to eq('message')
    end
  end
end
