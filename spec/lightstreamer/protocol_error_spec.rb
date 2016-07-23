describe Lightstreamer::ProtocolError do
  it 'constructs from an error message and error code' do
    error = Lightstreamer::ProtocolError.new 'message', '15'

    expect(error.error).to eq('message')
    expect(error.code).to eq(15)
    expect(error.message).to eq('Lightstreamer error: message, code: 15')
  end
end
