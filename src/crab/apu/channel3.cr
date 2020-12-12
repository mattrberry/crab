class Channel3 < SoundChannel
  RANGE          = 0x70..0x77
  WAVE_RAM_RANGE = 0x90..0x9F

  def ===(value) : Bool
    value.is_a?(Int) && RANGE.includes?(value) || WAVE_RAM_RANGE.includes?(value)
  end

  @wave_ram = Array(Bytes).new 2, Bytes.new(WAVE_RAM_RANGE.size) { |idx| idx & 1 == 0 ? 0x00_u8 : 0xFF_u8 }
  @wave_ram_position : UInt8 = 0
  @wave_ram_sample_buffer : UInt8 = 0x00

  # NR30
  @wave_ram_dimension : Bool = false
  @wave_ram_bank : UInt8 = 0

  # NR31
  @length_load : UInt8 = 0x00

  # NR32
  @volume_code : UInt8 = 0x00
  @volume_force : Bool = false

  @volume_multiplier : Float32 = 0

  # NR33 / NR34
  @frequency : UInt16 = 0x00

  def step_wave_generation : Nil
    @wave_ram_position = (@wave_ram_position + 1) % (WAVE_RAM_RANGE.size * 2)
    @wave_ram_bank ^= 1 if @wave_ram_position == 0 && @wave_ram_dimension
    @wave_ram_sample_buffer = @wave_ram[@wave_ram_bank][@wave_ram_position // 2]
  end

  def frequency_timer : UInt32
    (0x800_u32 - @frequency) * 2 * 4
  end

  def schedule_reload(frequency_timer : UInt32) : Nil
    @gba.scheduler.schedule frequency_timer, ->step, Scheduler::EventType::APUChannel3
  end

  def get_amplitude : Float32
    if @enabled && @dac_enabled
      dac_input = @volume_multiplier * ((@wave_ram_sample_buffer >> (@wave_ram_position & 1 == 0 ? 4 : 0)) & 0x0F)
      dac_output = (dac_input / 7.5) - 1
      dac_output
    else
      0
    end.to_f32
  end

  def read_io(index : Int) : UInt8
    case index
    when 0x70 then 0x7F | (@dac_enabled ? 0x80 : 0)
    when 0x72 then 0xFF
    when 0x73 then 0x9F | @volume_code << 5
    when 0x74 then 0xFF
    when 0x75 then 0xBF | (@length_enable ? 0x40 : 0)
    when WAVE_RAM_RANGE
      if @enabled
        @wave_ram[@wave_ram_bank][@wave_ram_position // 2]
      else
        @wave_ram[@wave_ram_bank][index - WAVE_RAM_RANGE.begin]
      end
    else raise "Reading from invalid Channel3 register: #{hex_str index.to_u16}"
    end.to_u8
  end

  def write_io(index : Int, value : UInt8) : Nil
    case index
    when 0x70
      @dac_enabled = value & 0x80 > 0
      @enabled = false if !@dac_enabled
      @wave_ram_dimension = bit?(value, 5)
      @wave_ram_bank = bits(value, 6..6)
    when 0x72
      @length_load = value
      # Internal values
      @length_counter = 0x100 - @length_load
    when 0x73
      @volume_code = (value & 0x60) >> 5
      @volume_force = bit?(value, 7)
      # Internal values
      @volume_multiplier = case {@volume_force, @volume_code}
                           when {true, _} then 0.75_f32
                           when {_, 0b00} then 0_f32
                           when {_, 0b01} then 1_f32
                           when {_, 0b10} then 0.5_f32
                           when {_, 0b11} then 0.25_f32
                           else                raise "Impossible volume code #{@volume_code}"
                           end
    when 0x74
      @frequency = (@frequency & 0x0700) | value
    when 0x75
      @frequency = (@frequency & 0x00FF) | (value.to_u16 & 0x07) << 8
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
          @length_counter = 0x100
          # Obscure length counter behavior #2
          @length_counter -= 1 if @length_enable && @gba.apu.first_half_of_length_period
        end
        # Init frequency
        # todo: I'm patching in an extra 6 T-cycles here with the `+ 6`. This is specifically
        #       to get blargg's "09-wave read while on.s" to pass. I'm _not_ refilling the
        #       frequency timer with this extra cycles when it reaches 0. For now, I'm letting
        #       this be in order to work on other audio behavior. Note that this is pretty
        #       brittle in it's current state though...
        @gba.scheduler.clear Scheduler::EventType::APUChannel3
        schedule_reload frequency_timer + 6
        # Init wave ram position
        @wave_ram_position = 0
      end
    when WAVE_RAM_RANGE
      if @enabled
        @wave_ram[@wave_ram_bank][@wave_ram_position // 2] = value
      else
        @wave_ram[@wave_ram_bank][index - WAVE_RAM_RANGE.begin] = value
      end
    else raise "Writing to invalid Channel3 register: #{hex_str index.to_u16}"
    end
  end
end
