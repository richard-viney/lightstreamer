describe Lightstreamer::StreamConnection do
  let(:session) do
    instance_double 'Lightstreamer::Session', server_url: 'http://test.com', username: 'username',
                                              password: 'password', adapter_set: 'set'
  end

  let(:http_stream) { instance_double 'Net::HTTP' }
  let(:http_create_request) { instance_double 'Net::HTTPRequest' }
  let(:http_create_response) { instance_double 'Net::HTTPResponse' }

  before do
    expect(Net::HTTP).to receive(:new).with('test.com', 80).and_return(http_stream)
    expect(Net::HTTP::Post).to receive(:new).with('/lightstreamer/create_session.txt').and_return(http_create_request)

    body = 'LS_op2=create&LS_cid=mgQkwtwdysogQz2BJ4Ji+kOj2Bg&LS_user=username&LS_password=password&LS_adapter_set=set'
    expect(http_create_request).to receive(:body=).with(body)
  end

  it 'creates and runs a stream connection' do
    expect(http_stream).to receive(:request).with(http_create_request).and_yield(http_create_response)
    expect(http_create_response).to receive(:read_body).and_yield("OK\r\nSessionId:A\r\n\r\none\r\ntwo\r\nLOOP\r\n")

    http_bind_request = instance_double 'Net::HTTPRequest'
    http_bind_response = instance_double 'Net::HTTPResponse'

    expect(Net::HTTP::Post).to receive(:new).with('/lightstreamer/bind_session.txt').and_return(http_bind_request)
    expect(http_bind_request).to receive(:body=).with('LS_session=A')
    expect(http_stream).to receive(:request).with(http_bind_request).and_yield(http_bind_response)
    expect(http_bind_response).to receive(:read_body).and_yield("OK\r\nSessionId:A\r\n\r\nthree\r\nfour\r\n")

    stream_connection = Lightstreamer::StreamConnection.new session
    stream_connection.connect

    expect(stream_connection.read_line).to eq('one')
    expect(stream_connection.read_line).to eq('two')
    expect(stream_connection.read_line).to eq('three')
    expect(stream_connection.read_line).to eq('four')

    stream_connection.disconnect
  end

  it 'reports and exits when an exception occurs on the stream thread' do
    expect(http_stream).to receive(:request).with(http_create_request).and_raise(StandardError)

    expect do
      stream_connection = Lightstreamer::StreamConnection.new session
      stream_connection.connect
    end.to output("Lightstreamer: exception in stream thread: StandardError\n").to_stderr.and raise_error(SystemExit)
  end
end
