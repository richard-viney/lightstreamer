describe Lightstreamer::StreamBuffer do
  it 'progressively parses a stream and yields stripped line data' do
    buffer = described_class.new

    expect { |block| buffer.process('A', &block) }.not_to yield_control
    expect { |block| buffer.process('B', &block) }.not_to yield_control
    expect { |block| buffer.process("C\r\n", &block) }.to yield_with_args('ABC')
    expect { |block| buffer.process("1\n", &block) }.to yield_with_args('1')
    expect { |block| buffer.process('2', &block) }.not_to yield_control
    expect { |block| buffer.process("3\r\n4\r\n", &block) }.to yield_successive_args('23', '4')
    expect { |block| buffer.process("\r\n5\r\n6", &block) }.to yield_successive_args('', '5')
  end
end
