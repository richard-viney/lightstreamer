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

  it 'processes a failure header in the expected format' do
    expect(header.process_header_line('ERROR')).to be true
    expect(header.process_header_line('10')).to be true
    expect(header.process_header_line('Error message')).to be false
    expect(header.error.code).to eq(10)
    expect(header.error.error).to eq('Error message')
  end

  it 'handles an unexpected format' do
    expect(header.process_header_line('Unexpected error format')).to be false
    expect(header.error.error).to eq('Unexpected error format')
  end
end
