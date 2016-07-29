describe Lightstreamer::ControlConnection do
  def build_response(body)
    instance_double 'Excon::Response', body: body
  end

  it 'handles a successful request' do
    expect(Excon).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: 'LS_session=session&LS_op=test&key=a+b',
                                                      connect_timeout: 15)
      .and_return(build_response("OK\r\n"))

    Lightstreamer::ControlConnection.execute 'http://a.com', 'session', :test, key: %w(a b), ignore_me: nil
  end

  it 'handles an error response' do
    expect(Excon).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: 'LS_session=session&LS_op=test', connect_timeout: 15)
      .and_return(build_response("ERROR\r\n1\r\nError message\r\n"))

    expect do
      Lightstreamer::ControlConnection.execute 'http://a.com', 'session', :test
    end.to raise_error(Lightstreamer::Errors::AuthenticationError)
  end

  it 'handles a sync error response' do
    expect(Excon).to receive(:post)
      .with('http://a.com/lightstreamer/control.txt', body: 'LS_session=session&LS_op=test', connect_timeout: 15)
      .and_return(build_response("SYNC ERROR\r\n"))

    expect do
      Lightstreamer::ControlConnection.execute 'http://a.com', 'session', :test
    end.to raise_error(Lightstreamer::Errors::SyncError)
  end

  it 'handles a request error' do
    expect(Excon).to receive(:post).and_raise(Excon::Error.new('Error message'))

    expect { Lightstreamer::ControlConnection.execute 'http://a.com', 'session', :operation }.to raise_error do |error|
      expect(error).to be_a(Lightstreamer::Errors::ConnectionError)
      expect(error.message).to eq('Error message')
    end
  end
end
