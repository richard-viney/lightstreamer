describe Lightstreamer::ControlConnection do
  let(:response) { instance_double 'Excon::Response' }

  let(:control_connection) { Lightstreamer::ControlConnection.new 'session', 'http://a.com' }

  def build_response(body)
    instance_double 'Excon::Response', body: body
  end

  it 'handles a successful request' do
    expect(Excon).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: 'LS_session=session&LS_op=test', connect_timeout: 15)
      .and_return(build_response("OK\r\n"))

    control_connection.execute :test
  end

  it 'handles an error response' do
    expect(Excon).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: 'LS_session=session&LS_op=test', connect_timeout: 15)
      .and_return(build_response("ERROR\r\n1\r\nError message\r\n"))

    expect { control_connection.execute :test }.to raise_error(Lightstreamer::Errors::AuthenticationError)
  end

  it 'handles a sync error response' do
    expect(Excon).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: 'LS_session=session&LS_op=test', connect_timeout: 15)
      .and_return(build_response("SYNC ERROR\r\n"))

    expect { control_connection.execute :test }.to raise_error(Lightstreamer::Errors::SyncError)
  end

  it 'handles a request error' do
    expect(Excon).to receive(:post).and_raise(Excon::Error.new('Error message'))

    expect { control_connection.execute :operation }.to raise_error do |error|
      expect(error).to be_a(Lightstreamer::Errors::ConnectionError)
      expect(error.message).to eq('Error message')
    end
  end

  it 'makes a subscription request' do
    body = 'LS_mode=MERGE&LS_data_adapter=adapter&LS_id=a+b&LS_schema=x+y&LS_table=1&LS_session=session&LS_op=add'

    expect(Excon).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: body, connect_timeout: 15)
      .and_return(build_response("OK\r\n"))

    control_connection.subscription_execute :add, 1, adapter: 'adapter', items: %w(a b), fields: %w(x y), mode: :merge
  end

  it 'ignores a nil subscription adapter' do
    body = 'LS_table=1&LS_session=session&LS_op=delete'

    expect(Excon).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: body, connect_timeout: 15)
      .and_return(build_response("OK\r\n"))

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
