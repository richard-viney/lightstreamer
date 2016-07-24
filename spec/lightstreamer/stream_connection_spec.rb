describe Lightstreamer::StreamConnection do
  let(:session) do
    instance_double 'Lightstreamer::Session', server_url: 'http://test.com', username: 'username',
                                              password: 'password', adapter_set: 'set'
  end

  let(:create_request) { instance_double 'Typhoeus::Request' }
  let(:create_response) { instance_double 'Typhoeus::Response' }
  let(:create_params) do
    { LS_op2: 'create', LS_cid: 'mgQkwtwdysogQz2BJ4Ji kOj2Bg', LS_user: 'username', LS_password: 'password',
      LS_adapter_set: 'set' }
  end

  before do
    expect(Typhoeus::Request).to receive(:new)
      .with('http://test.com/lightstreamer/create_session.txt', method: :post, params: create_params)
      .and_return(create_request)
  end

  it 'creates and runs a stream connection' do
    bind_request = instance_double 'Typhoeus::Request'
    bind_params = { LS_session: 'A' }

    on_body_block = nil

    expect(create_request).to receive(:on_body) { |&block| on_body_block = block }
    expect(create_request).to receive(:on_complete)
    expect(create_request).to receive(:run) do
      on_body_block.call "OK\r\nSessionId:A\r\n\r\none\r\ntwo\r\nLOOP\r\n"
    end

    expect(Typhoeus::Request).to receive(:new)
      .with('http://test.com/lightstreamer/bind_session.txt', method: :post, params: bind_params)
      .and_return(bind_request)

    expect(bind_request).to receive(:on_body) { |&block| on_body_block = block }
    expect(bind_request).to receive(:on_complete)
    expect(bind_request).to receive(:run) do
      on_body_block.call "OK\r\nSessionId:A\r\n\r\nthree\r\nfour\r\n"
      sleep
    end

    stream_connection = Lightstreamer::StreamConnection.new session
    stream_connection.connect

    expect(stream_connection.connected?).to be true

    expect(stream_connection.read_line).to eq('one')
    expect(stream_connection.read_line).to eq('two')
    expect(stream_connection.read_line).to eq('three')
    expect(stream_connection.read_line).to eq('four')

    stream_connection.disconnect

    expect(stream_connection.connected?).to be false
  end

  it 'handles an exception on the stream thread' do
    expect(create_request).to receive(:on_body).and_raise('test')

    stream_connection = Lightstreamer::StreamConnection.new session

    expect { stream_connection.connect }.to raise_error('test')

    expect(stream_connection.error.message).to eq('test')
    expect(stream_connection.connected?).to be false
  end

  it 'handles an HTTP error on the stream thread' do
    on_complete_block = nil

    expect(create_request).to receive(:on_body)
    expect(create_request).to receive(:on_complete) { |&block| on_complete_block = block }

    expect(create_request).to receive(:run) do
      on_complete_block.call create_response
    end

    expect(create_response).to receive(:success?).and_return(false)
    expect(create_response).to receive(:return_message).and_return('Error message')
    expect(create_response).to receive(:response_code).and_return(404)

    expect { Lightstreamer::StreamConnection.new(session).connect }.to raise_error do |error|
      expect(error).to be_a(Lightstreamer::RequestError)
      expect(error.error).to eq('Error message')
      expect(error.http_code).to eq(404)
    end
  end
end
