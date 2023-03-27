describe Lightstreamer::SendMessageOutcomeMessage do
  it 'parses a success message' do
    message = described_class.parse 'MSG,Name_123,99,DONE'

    expect(message.sequence).to eq('Name_123')
    expect(message.numbers).to eq([99])
    expect(message.error).to be_nil
  end

  it 'parses a failure message' do
    message = described_class.parse 'MSG,Name,1,ERR,34,Message,DONE'

    expect(message.sequence).to eq('Name')
    expect(message.numbers).to eq([1])
    expect(message.error).to be_a(Lightstreamer::Errors::IllegalMessageError)
  end

  it 'parses a multiple messages skipped by timeout error' do
    outcome = described_class.parse 'MSG,Name,4,ERR,39,3'

    expect(outcome.numbers).to eq([2, 3, 4])
    expect(outcome.error).to be_a(Lightstreamer::Errors::MessagesSkippedByTimeoutError)
  end

  it 'rejects invalid messages' do
    ['', 'DONE', 'MSG,,99,DONE', 'MSG,-,99,DONE', 'MSG,Name,99,ERR,A,A'].each do |line|
      expect(described_class.parse(line)).to be_nil
    end
  end
end
