describe Lightstreamer::StreamBuffer do
  it 'progressively parses a stream and yields stripped line data' do
    buffer = Lightstreamer::StreamBuffer.new

    expect { |block| buffer.process('A', &block) }.to_not yield_control
    expect { |block| buffer.process('B', &block) }.to_not yield_control
    expect { |block| buffer.process("C\r\n", &block) }.to yield_with_args('ABC')
    expect { |block| buffer.process("1\n", &block) }.to yield_with_args('1')
    expect { |block| buffer.process('2', &block) }.to_not yield_control
    expect { |block| buffer.process("3\r\n4", &block) }.to yield_with_args('23')
    expect { |block| buffer.process("\r\n5", &block) }.to yield_with_args('4')
  end
end
