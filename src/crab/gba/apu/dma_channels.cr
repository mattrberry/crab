module GBA
  class DMAChannels
    RANGE = 0xA0..0xA7

    @fifos = Slice(Slice(Int8)).new 2 { Slice(Int8).new 32, 0 }
    @positions = Slice(Int32).new 2, 0
    @sizes = Slice(Int32).new 2, 0
    @timers : Slice(Proc(UInt16))
    @latches = Slice(Int16).new 2, 0

    def ===(other) : Bool
      other.is_a?(Int) && RANGE.includes?(other)
    end

    def initialize(@gba : GBA, @control : Reg::SOUNDCNT_H)
      @timers = Slice[
        ->{ @control.dma_sound_a_timer },
        ->{ @control.dma_sound_b_timer },
      ]
    end

    def [](address : UInt32) : UInt8
      @gba.bus.read_open_bus_value(address)
    end

    def []=(address : UInt32, value : UInt8) : Nil
      channel = bit?(address, 2).to_unsafe
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
end
