module GBA
  class Channel4 < VolumeEnvelopeChannel
    RANGE = 0x78..0x7F

    def ===(other) : Bool
      other.is_a?(Int) && RANGE.includes?(other)
    end

    @lfsr : UInt16 = 0x0000

    # NR41
    @length_load : UInt8 = 0x00

    # NR43
    @clock_shift : UInt8 = 0x00
    @width_mode : UInt8 = 0x00
    @divisor_code : UInt8 = 0x00

    def step_wave_generation : Nil
      new_bit = (@lfsr & 0b01) ^ ((@lfsr & 0b10) >> 1)
      @lfsr >>= 1
      @lfsr |= new_bit << 14
      if @width_mode != 0
        @lfsr &= ~(1 << 6)
        @lfsr |= new_bit << 6
      end
    end

    def frequency_timer : UInt32
      ((@divisor_code == 0 ? 8_u32 : @divisor_code.to_u32 << 4) << @clock_shift) * 4
    end

    def schedule_reload(frequency_timer : UInt32) : Nil
      @gba.scheduler.schedule frequency_timer, ->step, Scheduler::EventType::APUChannel4
    end

    # Outputs a value -0x80..0x80
    def get_amplitude : Int16
      if @enabled && @dac_enabled
        ((~@lfsr & 1).to_i16 * 16 - 8) * @current_volume
      else
        0_i16
      end
    end

    def [](address : UInt32) : UInt8
      case address
      when 0x79 then read_NRx2
      when 0x7C then @clock_shift << 4 | @width_mode << 3 | @divisor_code
      when 0x7D then (@length_enable ? 0x40_u8 : 0_u8)
      else           0_u8
      end
    end

    def []=(address : UInt32, value : UInt8) : Nil
      case address
      when 0x78
        @length_load = value & 0x3F
        # Internal values
        @length_counter = 0x40 - @length_load
      when 0x79
        write_NRx2 value
      when 0x7A # not used
      when 0x7B # not used
      when 0x7C
        @clock_shift = value >> 4
        @width_mode = (value & 0x08) >> 3
        @divisor_code = value & 0x07
      when 0x7D
        length_enable = value & 0x40 > 0
        # Obscure length counter behavior #1
        if @gba.apu.first_half_of_length_period && !@length_enable && length_enable && @length_counter > 0
          @length_counter -= 1
          @enabled = false if @length_counter == 0
        end
        @length_enable = length_enable
        trigger = value & 0x80 > 0
        if trigger
          @enabled = true if @dac_enabled
          # Init length
          if @length_counter == 0
            @length_counter = 0x40
            # Obscure length counter behavior #2
            @length_counter -= 1 if @length_enable && @gba.apu.first_half_of_length_period
          end
          # Init frequency
          @gba.scheduler.clear Scheduler::EventType::APUChannel4
          schedule_reload frequency_timer
          # Init volume envelope
          init_volume_envelope
          # Init lfsr
          @lfsr = 0x7FFF
        end
      when 0x7E # not used
      when 0x7F # not used
      else raise "Writing to invalid Channel4 register: #{hex_str address.to_u16}"
      end
    end
  end
end
