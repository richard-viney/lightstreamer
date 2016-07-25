describe Lightstreamer::StreamConnectionHeader do
  let(:header) { Lightstreamer::StreamConnectionHeader.new }

  it 'processes a success header' do
    expect(header.process_header_line('OK')).to be true
    expect(header.process_header_line('SessionId:123')).to be true
    expect(header.process_header_line('ControlAddress:abc')).to be true
    expect(header.process_header_line('')).to be false

    expect(header['SessionId']).to eq('123')
    expect(header['ControlAddress']).to eq('abc')
  end

  it 'processes an error header' do
    expect(header.process_header_line('ERROR')).to be true
    expect(header.process_header_line('1')).to be true
    expect(header.process_header_line('')).to be true

    expect(header.error).to be_a(Lightstreamer::AuthenticationError)
  end

  it 'processes an end header' do
    expect(header.process_header_line('END')).to be true

    expect(header.error).to be_a(Lightstreamer::SessionEndError)
  end

  it 'processes an end header with a cause code' do
    expect(header.process_header_line('END')).to be true
    expect(header.process_header_line('31')).to be true

    expect(header.error).to be_a(Lightstreamer::SessionEndError)
    expect(header.error.cause_code).to eq(31)
  end

  it 'processes a sync error' do
    expect(header.process_header_line('SYNC ERROR')).to be false

    expect(header.error).to be_a(Lightstreamer::SyncError)
  end

  it 'processes an unrecognized error' do
    expect(header.process_header_line('Unknown')).to be true
    expect(header.process_header_line('data')).to be true

    expect(header.error).to be_a(Lightstreamer::Error)
    expect(header.error.message).to eq('Unknown data')
  end
end
