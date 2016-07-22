describe Lightstreamer::RequestError do
  it 'constructs from an error message' do
    error = Lightstreamer::RequestError.new 'message'

    expect(error.error).to eq('message')
    expect(error.http_code).to be_nil
    expect(error.message).to eq('Request error: message>')
  end

  it 'constructs from an error message and HTTP code' do
    error = Lightstreamer::RequestError.new 'message', '404'

    expect(error.error).to eq('message')
    expect(error.http_code).to eq(404)
    expect(error.message).to eq('Request error: message, http code: 404')
  end
end
