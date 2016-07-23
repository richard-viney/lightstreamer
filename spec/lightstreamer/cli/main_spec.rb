describe Lightstreamer::CLI::Main do
  it 'bootstraps' do
    expect(Lightstreamer::CLI::Main).to receive(:start).with([])

    Lightstreamer::CLI::Main.bootstrap []
  end

  it 'reports the version' do
    ['-v', '--version'].each do |argument|
      expect do
        Lightstreamer::CLI::Main.bootstrap [argument]
      end.to output("#{Lightstreamer::VERSION}\n").to_stdout.and raise_error(SystemExit)
    end
  end
end
