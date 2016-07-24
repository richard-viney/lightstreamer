describe Lightstreamer::ControlConnection do
  let(:response) { instance_double 'Typhoeus::Response' }

  let(:control_connection) { Lightstreamer::ControlConnection.new 'session', 'http://a.com' }

  it 'handles a successful request' do
    body = { LS_session: 'session', LS_table: 1, LS_op: :add, LS_data_adapter: 'adapter', LS_id: 'a b',
             LS_schema: 'x y', LS_mode: 'MERGE' }

    expect(Typhoeus).to receive(:post).with('http://a.com/lightstreamer/control.txt', body: body).and_return(response)
    expect(response).to receive(:success?).and_return(true)
    expect(response).to receive(:body).and_return("OK\r\n")

    control_connection.execute table: 1, operation: :add, adapter: 'adapter', items: %w(a b),
                               fields: %w(x y), mode: :merge
  end

  it 'handles an unsuccessful request' do
    body = { LS_session: 'session', LS_table: 1, LS_op: :delete }

    expect(Typhoeus).to receive(:post).with('http://a.com/lightstreamer/control.txt', body: body).and_return(response)
    expect(response).to receive(:success?).and_return(true)
    expect(response).to receive(:body).and_return("ERROR\r\n10\r\nError message\r\n")

    expect { control_connection.execute table: 1, operation: :delete }.to raise_error(Lightstreamer::ProtocolError)
  end

  it 'handles a request error' do
    expect(Typhoeus).to receive(:post).and_return(response)
    expect(response).to receive(:success?).and_return(false)
    expect(response).to receive(:return_message).and_return('Error message')
    expect(response).to receive(:response_code).and_return(404)

    expect { control_connection.execute table: 1, operation: :delete }.to raise_error do |error|
      expect(error).to be_a(Lightstreamer::RequestError)
      expect(error.error).to eq('Error message')
      expect(error.http_code).to eq(404)
    end
  end
end
