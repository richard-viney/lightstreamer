describe Lightstreamer::StreamConnection do
  let(:session) do
    instance_double 'Lightstreamer::Session', server_url: 'http://test.com', username: 'username',
                                              password: 'password', adapter_set: 'set'
  end

  let(:http_stream) { instance_double 'Net::HTTP' }
  let(:http_request) { instance_double 'Net::HTTPRequest' }
  let(:http_response) { instance_double 'Net::HTTPResponse' }

  before do
    body = 'LS_op2=create&LS_cid=mgQkwtwdysogQz2BJ4Ji+kOj2Bg&LS_user=username&LS_password=password&LS_adapter_set=set'

    expect(Net::HTTP::Post).to receive(:new).with('/lightstreamer/create_session.txt').and_return(http_request)
    expect(http_request).to receive(:body=).with(body)
    expect(Net::HTTP).to receive(:new).with('test.com', 80).and_return(http_stream)
  end

  it 'creates and runs a stream connection' do
    expect(http_stream).to receive(:request).with(http_request).and_yield(http_response)
    expect(http_response).to receive(:read_body).and_yield("ONE\r\n").and_yield("PROBE\r\n").and_yield("TWO\r\n")

    stream_connection = Lightstreamer::StreamConnection.new session

    expect(stream_connection.read_line).to eq('ONE')
    expect(stream_connection.read_line).to eq('TWO')

    stream_connection.disconnect
  end

  it 'reports and exits when an exception occurs on the stream thread' do
    expect(http_stream).to receive(:request).with(http_request).and_raise(StandardError)

    expect do
      stream_connection = Lightstreamer::StreamConnection.new session
      stream_connection.thread.join
    end.to output("Lightstreamer: exception in stream thread: StandardError\n").to_stderr.and raise_error(SystemExit)
  end
end
