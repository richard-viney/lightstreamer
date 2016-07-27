describe Lightstreamer::StreamConnectionHeader do
  let(:header) { Lightstreamer::StreamConnectionHeader.new }

  it 'processes a success header' do
    expect(header.process_line('OK')).to be true
    expect(header.process_line('SessionId:123')).to be true
    expect(header.process_line('ControlAddress:abc')).to be true
    expect(header.process_line('')).to be false

    expect(header['SessionId']).to eq('123')
    expect(header['ControlAddress']).to eq('abc')
  end

  it 'processes an error header' do
    expect(header.process_line('ERROR')).to be true
    expect(header.process_line('1')).to be true
    expect(header.process_line('')).to be true

    expect(header.error).to be_a(Lightstreamer::Errors::AuthenticationError)
  end

  it 'processes an end header' do
    expect(header.process_line('END')).to be true

    expect(header.error).to be_a(Lightstreamer::Errors::SessionEndError)
  end

  it 'processes an end header with a cause code' do
    expect(header.process_line('END')).to be true
    expect(header.process_line('31')).to be true

    expect(header.error).to be_a(Lightstreamer::Errors::SessionEndError)
    expect(header.error.cause_code).to eq(31)
  end

  it 'processes a sync error' do
    expect(header.process_line('SYNC ERROR')).to be false

    expect(header.error).to be_a(Lightstreamer::Errors::SyncError)
  end

  it 'processes an unrecognized error' do
    expect(header.process_line('Unknown')).to be true
    expect(header.process_line('data')).to be true

    expect(header.error).to be_a(Lightstreamer::LightstreamerError)
    expect(header.error.message).to eq('Unknown data')
  end
end
