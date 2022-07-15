module GB
  class Channel3 < SoundChannel
    RANGE          = 0xFF1A..0xFF1E
    WAVE_RAM_RANGE = 0xFF30..0xFF3F

    def ===(other) : Bool
      other.is_a?(Int) && RANGE.includes?(other) || WAVE_RAM_RANGE.includes?(other)
    end

    @wave_ram = Bytes.new(WAVE_RAM_RANGE.size) { |idx| idx & 1 == 0 ? 0x00_u8 : 0xFF_u8 }
    @wave_ram_position : UInt8 = 0
    @wave_ram_sample_buffer : UInt8 = 0x00

    # NR31
    @length_load : UInt8 = 0x00

    # NR32
    @volume_code : UInt8 = 0x00

    @volume_code_shift : UInt8 = 0

    # NR33 / NR34
    @frequency : UInt16 = 0x00

    def step_wave_generation : Nil
      @wave_ram_position = (@wave_ram_position + 1) % (WAVE_RAM_RANGE.size * 2)
      @wave_ram_sample_buffer = @wave_ram[@wave_ram_position // 2]
    end

    def frequency_timer : UInt32
      (0x800_u32 - @frequency) * 2
    end

    def schedule_reload(frequency_timer : UInt32) : Nil
      @gb.scheduler.schedule_gb frequency_timer, ->step, Scheduler::EventType::APUChannel3
    end

    def get_amplitude : Float32
      if @enabled && @dac_enabled
        dac_input = ((@wave_ram_sample_buffer >> (@wave_ram_position & 1 == 0 ? 4 : 0)) & 0x0F) >> @volume_code_shift
        dac_output = (dac_input / 7.5) - 1
        dac_output.to_f32
      else
        0_f32
      end
    end

    def [](index : Int) : UInt8
      case index
      when 0xFF1A then 0x7F_u8 | (@dac_enabled ? 0x80 : 0)
      when 0xFF1B then 0xFF_u8
      when 0xFF1C then 0x9F_u8 | @volume_code << 5
      when 0xFF1D then 0xFF_u8
      when 0xFF1E then 0xBF_u8 | (@length_enable ? 0x40 : 0)
      when WAVE_RAM_RANGE
        if @enabled
          @wave_ram[@wave_ram_position // 2]
        else
          @wave_ram[index - WAVE_RAM_RANGE.begin]
        end
      else raise "Reading from invalid Channel3 register: #{hex_str index.to_u16}"
      end
    end

    def []=(index : Int, value : UInt8) : Nil
      case index
      when 0xFF1A
        @dac_enabled = value & 0x80 > 0
        @enabled = false if !@dac_enabled
      when 0xFF1B
        @length_load = value
        # Internal values
        @length_counter = 0x100 - @length_load
      when 0xFF1C
        @volume_code = (value & 0x60) >> 5
        # Internal values
        @volume_code_shift = case @volume_code
                             when 0b00 then 4_u8
                             when 0b01 then 0_u8
                             when 0b10 then 1_u8
                             when 0b11 then 2_u8
                             else           raise "Impossible volume code #{@volume_code}"
                             end
      when 0xFF1D
        @frequency = (@frequency & 0x0700) | value
      when 0xFF1E
        @frequency = (@frequency & 0x00FF) | (value.to_u16 & 0x07) << 8
        length_enable = value & 0x40 > 0
        # Obscure length counter behavior #1
        if @gb.apu.first_half_of_length_period && !@length_enable && length_enable && @length_counter > 0
          @length_counter -= 1
          @enabled = false if @length_counter == 0
        end
        @length_enable = length_enable
        trigger = value & 0x80 > 0
        if trigger
          log "triggered"
          log "  NR30:      dac_enabled:#{@dac_enabled}"
          log "  NR31:      length_load:#{@length_load}"
          log "  NR32:      volume_code:#{@volume_code}"
          log "  NR33/NR34: frequency:#{@frequency}, length_enable:#{@length_enable}"
          @enabled = true if @dac_enabled
          # Init length
          if @length_counter == 0
            @length_counter = 0x100
            # Obscure length counter behavior #2
            @length_counter -= 1 if @length_enable && @gb.apu.first_half_of_length_period
          end
          # Init frequency
          # todo: I'm patching in an extra 6 T-cycles here with the `+ 6`. This is specifically
          #       to get blargg's "09-wave read while on.s" to pass. I'm _not_ refilling the
          #       frequency timer with this extra cycles when it reaches 0. For now, I'm letting
          #       this be in order to work on other audio behavior. Note that this is pretty
          #       brittle in it's current state though...
          @gb.scheduler.clear Scheduler::EventType::APUChannel3
          schedule_reload frequency_timer + 6
          # Init wave ram position
          @wave_ram_position = 0
        end
      when WAVE_RAM_RANGE
        if @enabled
          @wave_ram[@wave_ram_position // 2] = value
        else
          @wave_ram[index - WAVE_RAM_RANGE.begin] = value
        end
      else raise "Writing to invalid Channel3 register: #{hex_str index.to_u16}"
      end
    end
  end
end
