class DMAChannels
  RANGE = 0xA0..0xA7

  @fifos = Array(Array(Int8)).new 2 { Array(Int8).new 32, 0 }
  @positions = Array(Int32).new 2, 0
  @sizes = Array(Int32).new 2, 0
  @timers : Array(Proc(UInt16))
  @latches = Array(Float32).new 2, 0

  def ===(value) : Bool
    value.is_a?(Int) && RANGE.includes?(value)
  end

  def initialize(@gba : GBA, @control : Reg::SOUNDCNT_H)
    @timers = [
      ->{ @control.dma_sound_a_timer },
      ->{ @control.dma_sound_b_timer },
    ]
  end

  def read_io(index : Int) : UInt8
    0_u8
  end

  def write_io(index : Int, value : Byte) : Nil
    puts "DMA FIFO write: #{hex_str index.to_u16} -> #{hex_str value}"
    channel = bit?(index, 2).to_unsafe
    if @sizes[channel] < 32
      @fifos[channel][(@positions[channel] + @sizes[channel]) % 32] = value.to_i8!
      @sizes[channel] += 1
    else
      puts "  Writing #{hex_str value} to fifo #{(channel + 65).chr}, but it's already full".colorize.fore(:red)
    end
  end

  def timer_overflow(timer : Int) : Nil
    (0..1).each do |channel|
      if timer == @timers[channel].call
        if @sizes[channel] > 0
          @latches[channel] = (@fifos[channel][@positions[channel]] / 128).to_f32
          @positions[channel] = (@positions[channel] + 1) % 32
          @sizes[channel] -= 1
        else
          puts "Timer overflow but empty".colorize.fore(:yellow)
          @latches[channel] = 0
        end
      end
      puts "Triggering dma for channel #{channel} / #{channel + 1}" if @sizes[channel] < 16
      @gba.dma.trigger channel + 1 if @sizes[channel] < 16
    end
  end

  def get_amplitude : Tuple(Float32, Float32)
    {@latches[0], @latches[1]}
  end
end
