describe Lightstreamer::CLI::Main do
  it 'bootstraps' do
    expect(described_class).to receive(:start).with([])

    described_class.bootstrap []
  end

  it 'reports the version' do
    ['-v', '--version'].each do |argument|
      expect do
        described_class.bootstrap [argument]
      end.to output("#{Lightstreamer::VERSION}\n").to_stdout.and raise_error(SystemExit)
    end
  end
end
