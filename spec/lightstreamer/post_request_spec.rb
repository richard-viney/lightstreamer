describe Lightstreamer::PostRequest do
  def build_response(body)
    instance_double Excon::Response, body: body
  end

  it 'sends a single request' do
    expect(Excon).to receive(:post)
      .with('http://a.com', body: 'number=1&items=a+b', expects: 200, connect_timeout: 15)
      .and_return(build_response("OK\r\n"))

    described_class.execute 'http://a.com', number: 1, items: %w[a b], ignore_me: nil
  end

  it 'handles a standard error response to a single request' do
    expect(Excon).to receive(:post)
      .with('http://a.com', body: 'test=1', expects: 200, connect_timeout: 15)
      .and_return(build_response("ERROR\r\n1\r\nError message\r\n"))

    expect do
      described_class.execute 'http://a.com', test: 1
    end.to raise_error(Lightstreamer::Errors::AuthenticationError)
  end

  it 'handles a sync error response to a single request' do
    expect(Excon).to receive(:post)
      .with('http://a.com', body: 'test=1', expects: 200, connect_timeout: 15)
      .and_return(build_response("SYNC ERROR\r\n"))

    expect do
      described_class.execute 'http://a.com', test: 1
    end.to raise_error(Lightstreamer::Errors::SyncError)
  end

  it 'handles a connection error response to a single request' do
    expect(Excon).to receive(:post).and_raise(Excon::Error.new('Error message'))

    expect { described_class.execute 'http://a.com', test: 1 }.to raise_error do |error|
      expect(error).to be_a(Lightstreamer::Errors::ConnectionError)
      expect(error.message).to eq('Error message')
    end
  end

  it 'sends multiple requests and reports any errors' do
    expect(Excon).to receive(:post)
      .with('http://a.com', body: "A\r\nB\r\nC", connect_timeout: 15, expects: 200)
      .and_return(build_response("OK\r\nERROR\r\n2\r\nERROR MESSAGE\r\nINVALID RESPONSE\r\n"))

    errors = described_class.execute_multiple 'http://a.com', %w[A B C]

    expect(errors.size).to eq(3)
    expect(errors[0]).to be_nil
    expect(errors[1]).to be_a(Lightstreamer::Errors::UnknownAdapterSetError)
    expect(errors[2]).to be_a(Lightstreamer::LightstreamerError)
    expect(errors[2].message).to eq('INVALID RESPONSE')
  end

  it 'handles invalid responses for multiple requests' do
    expect(Excon).to receive(:post)
      .with('http://a.com', body: "body1\r\nbody2", connect_timeout: 15, expects: 200)
      .and_return(build_response("OK\r\nOK\r\nOK\r\n"))

    expect do
      described_class.execute_multiple 'http://a.com', %w[body1 body2]
    end.to raise_error(Lightstreamer::LightstreamerError)
  end
end
