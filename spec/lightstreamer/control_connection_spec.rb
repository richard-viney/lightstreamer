describe Lightstreamer::ControlConnection do
  let(:response) { instance_double 'RestClient::Response' }

  let(:control_connection) { Lightstreamer::ControlConnection.new 'session', 'http://test.com' }

  it 'handles a successful request' do
    payload = 'LS_session=session&LS_table=1&LS_op=add&LS_data_adapter=adapter&LS_id=a+b&LS_schema=x+y&LS_mode=MERGE'

    expect(response).to receive(:body).and_return("OK\r\n")

    expect(RestClient::Request).to receive(:execute)
      .with(method: :post, url: 'http://test.com/lightstreamer/control.txt', payload: payload)
      .and_return(response)

    control_connection.execute table: 1, operation: :add, adapter: 'adapter', items: %w(a b),
                               fields: %w(x y), mode: :merge
  end

  it 'handles an unsuccessful request' do
    expect(response).to receive(:body).and_return("ERROR\r\n10\r\nError message\r\n")

    expect(RestClient::Request).to receive(:execute)
      .with(method: :post, url: 'http://test.com/lightstreamer/control.txt',
            payload: 'LS_session=session&LS_table=1&LS_op=delete')
      .and_return(response)

    expect { control_connection.execute table: 1, operation: :delete }.to raise_error(Lightstreamer::ProtocolError)
  end

  it 'handles an unsuccessful request' do
    expect(response).to receive(:body).and_return("ERROR\r\n10\r\nError message\r\n")

    expect(RestClient::Request).to receive(:execute)
      .with(method: :post, url: 'http://test.com/lightstreamer/control.txt',
            payload: 'LS_session=session&LS_table=1&LS_op=delete')
      .and_return(response)

    expect { control_connection.execute table: 1, operation: :delete }.to raise_error(Lightstreamer::ProtocolError)
  end

  it 'handles a request error' do
    expect(RestClient::Request).to receive(:execute).and_raise(RestClient::Exception)

    expect { control_connection.execute table: 1, operation: :delete }.to raise_error(Lightstreamer::RequestError)
  end

  it 'handles a socket error' do
    expect(RestClient::Request).to receive(:execute).and_raise(SocketError)

    expect { control_connection.execute table: 1, operation: :delete }.to raise_error(Lightstreamer::RequestError)
  end
end
