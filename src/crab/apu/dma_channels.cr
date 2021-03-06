class DMAChannels
  RANGE = 0xA0..0xA7

  @fifos = Array(Array(Int8)).new 2 { Array(Int8).new 32, 0 }
  @positions = Array(Int32).new 2, 0
  @sizes = Array(Int32).new 2, 0
  @timers : Array(Proc(UInt16))
  @latches = Array(Int16).new 2, 0

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
    channel = bit?(index, 2).to_unsafe
    if @sizes[channel] < 32
      @fifos[channel][(@positions[channel] + @sizes[channel]) % 32] = value.to_i8!
      @sizes[channel] += 1
    else
      log "Writing #{hex_str value} to fifo #{(channel + 65).chr}, but it's already full".colorize.fore(:red)
    end
  end

  def timer_overflow(timer : Int) : Nil
    2.times do |channel|
      if timer == @timers[channel].call
        if @sizes[channel] > 0
          log "Timer overflow good; channel:#{channel}, timer:#{timer}".colorize.fore(:yellow)
          @latches[channel] = @fifos[channel][@positions[channel]].to_i16 << 1 # put on scale of -0x100..0x100
          @positions[channel] = (@positions[channel] + 1) % 32
          @sizes[channel] -= 1
        else
          log "Timer overflow but empty; channel:#{channel}, timer:#{timer}".colorize.fore(:yellow)
          @latches[channel] = 0
        end
      end
      @gba.dma.trigger_fifo(channel) if @sizes[channel] < 16
    end
  end

  # Outputs a value -0x100...0x100
  def get_amplitude : Tuple(Int16, Int16)
    {@latches[0], @latches[1]}
  end
end
