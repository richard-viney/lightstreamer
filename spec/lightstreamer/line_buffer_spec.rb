describe Lightstreamer::LineBuffer do
  it 'progressively parses and strips line data' do
    line_buffer = Lightstreamer::LineBuffer.new

    expect { |block| line_buffer.process('A', &block) }.to_not yield_control
    expect { |block| line_buffer.process('B', &block) }.to_not yield_control
    expect { |block| line_buffer.process("C\r\n", &block) }.to yield_with_args('ABC')
    expect { |block| line_buffer.process("1\n", &block) }.to yield_with_args('1')
    expect { |block| line_buffer.process('2', &block) }.to_not yield_control
    expect { |block| line_buffer.process("3\r\n4", &block) }.to yield_with_args('23')
    expect { |block| line_buffer.process("\r\n5", &block) }.to yield_with_args('4')
  end
end
