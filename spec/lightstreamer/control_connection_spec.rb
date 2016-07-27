describe Lightstreamer::ControlConnection do
  let(:response) { instance_double 'Typhoeus::Response' }

  let(:control_connection) { Lightstreamer::ControlConnection.new 'session', 'http://a.com' }

  it 'handles a successful request' do
    body = { LS_session: 'session', LS_op: :test }

    expect(Typhoeus).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: body, timeout: 15)
      .and_return(response)

    expect(response).to receive(:success?).and_return(true)
    expect(response).to receive(:body).and_return("OK\r\n")

    control_connection.execute :test
  end

  it 'handles an error response' do
    body = { LS_session: 'session', LS_op: :test }

    expect(Typhoeus).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: body, timeout: 15)
      .and_return(response)

    expect(response).to receive(:success?).and_return(true)
    expect(response).to receive(:body).and_return("ERROR\r\n1\r\nError message\r\n")

    expect { control_connection.execute :test }.to raise_error(Lightstreamer::Errors::AuthenticationError)
  end

  it 'handles a sync error response' do
    body = { LS_session: 'session', LS_op: :test }

    expect(Typhoeus).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: body, timeout: 15)
      .and_return(response)

    expect(response).to receive(:success?).and_return(true)
    expect(response).to receive(:body).and_return("SYNC ERROR\r\n")

    expect { control_connection.execute :test }.to raise_error(Lightstreamer::Errors::SyncError)
  end

  it 'handles a request error' do
    expect(Typhoeus).to receive(:post).and_return(response)
    expect(response).to receive(:success?).and_return(false)
    expect(response).to receive(:return_message).and_return('Error message')
    expect(response).to receive(:response_code).and_return(404)

    expect { control_connection.execute :operation }.to raise_error do |error|
      expect(error).to be_a(Lightstreamer::Errors::RequestError)
      expect(error.request_error_message).to eq('Error message')
      expect(error.request_error_code).to eq(404)
    end
  end

  it 'makes a subscription request' do
    body = { LS_session: 'session', LS_table: 1, LS_op: :add, LS_data_adapter: 'adapter', LS_id: 'a b',
             LS_schema: 'x y', LS_mode: 'MERGE' }

    expect(Typhoeus).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: body, timeout: 15)
      .and_return(response)

    expect(response).to receive(:success?).and_return(true)
    expect(response).to receive(:body).and_return("OK\r\n")

    control_connection.subscription_execute :add, 1, adapter: 'adapter', items: %w(a b), fields: %w(x y), mode: :merge
  end

  it 'ignores a nil subscription adapter' do
    body = { LS_session: 'session', LS_table: 1, LS_op: :delete }

    expect(Typhoeus).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: body, timeout: 15)
      .and_return(response)

    expect(response).to receive(:success?).and_return(true)
    expect(response).to receive(:body).and_return('OK')

    control_connection.subscription_execute :delete, 1, adapter: nil
  end

  it 'raises an error on invalid subscription options' do
    [
      [:invalid, 1],
      [:add, '1'],
      [:add, 1, { items: nil, fields: nil }],
      [:add, 1, { items: nil, fields: nil }],
      [:add, 1, { items: nil, fields: nil }],
      [:add, 1, { items: nil, fields: nil }],
      [:add, 1, { items: nil, fields: nil }],
      [:add, 1, { items: nil, fields: nil }],
      [:add, 1, { items: [], fields: [] }],
      [:add, 1, { items: ['a'], fields: [] }],
      [:add, 1, { items: [], fields: ['a'] }],
      [:add, 1, { items: ['1'], fields: ['a'] }],
      [:add, 1, { items: ['1'], fields: ['a'], mode: :invalid }]
    ].each do |args|
      expect { control_connection.subscription_execute(*args) }.to raise_error(ArgumentError)
    end
  end
end
