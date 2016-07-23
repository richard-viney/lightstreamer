describe Lightstreamer::Session do
  let(:session) do
    Lightstreamer::Session.new server_url: 'http://test.com', username: 'username', password: 'password',
                               adapter_set: 'adapter-set'
  end

  let(:stream_connection) { instance_double 'Lightstreamer::StreamConnection' }
  let(:control_connection) { instance_double 'Lightstreamer::ControlConnection' }

  it '' do
    expect(Lightstreamer::StreamConnection).to receive(:new).and_return(stream_connection)
    expect(Lightstreamer::ControlConnection).to receive(:new).and_return(control_connection)

    expect(stream_connection).to receive(:read_line).and_return('OK')
    expect(stream_connection).to receive(:read_line).and_return('SessionId:session_id')
    expect(stream_connection).to receive(:read_line).and_return('ControlAddress:test2.com')
    expect(stream_connection).to receive(:read_line).and_return('KeepaliveMillis:5000')
    expect(stream_connection).to receive(:read_line).and_return('MaxBandwidth:0')
    expect(stream_connection).to receive(:read_line).and_return('')

    allow(stream_connection).to receive(:read_line).and_return('')

    expect(stream_connection).to receive(:disconnect)

    session.connect
    session.disconnect
  end

  it 'handles when the stream connection fails to connect' do
    expect(Lightstreamer::StreamConnection).to receive(:new).and_return(stream_connection)

    expect(stream_connection).to receive(:read_line).and_return('ERROR')
    expect(stream_connection).to receive(:read_line).and_return('10')
    expect(stream_connection).to receive(:read_line).and_return('Error message')

    expect { session.connect }.to raise_error do |error|
      expect(error).to be_a(Lightstreamer::ProtocolError)
      expect(error.error).to eq('Error message')
      expect(error.code).to eq(10)
    end
  end
end
