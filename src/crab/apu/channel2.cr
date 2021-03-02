class Channel2 < VolumeEnvelopeChannel
  WAVE_DUTY = [
    [-8, -8, -8, -8, -8, -8, -8, +8], # 12.5%
    [+8, -8, -8, -8, -8, -8, -8, +8], # 25%
    [+8, -8, -8, -8, -8, +8, +8, +8], # 50%
    [-8, +8, +8, +8, +8, +8, +8, -8], # 75%
  ]

  RANGE = 0x68..0x6F

  def ===(value) : Bool
    value.is_a?(Int) && RANGE.includes?(value)
  end

  @wave_duty_position = 0

  # NR21
  @duty : UInt8 = 0x00
  @length_load : UInt8 = 0x00

  # NR23 / NR24
  @frequency : UInt16 = 0x00

  def step_wave_generation : Nil
    @wave_duty_position = (@wave_duty_position + 1) & 7
  end

  def frequency_timer : UInt32
    (0x800_u32 - @frequency) * 4 * 4
  end

  def schedule_reload(frequency_timer : UInt32) : Nil
    @gba.scheduler.schedule frequency_timer, ->step, Scheduler::EventType::APUChannel2
  end

  # Outputs a value -0x80..0x80
  def get_amplitude : Int16
    if @enabled && @dac_enabled
      WAVE_DUTY[@duty][@wave_duty_position].to_i16 * @current_volume
    else
      0_i16
    end
  end

  def read_io(index : Int) : UInt8
    case index
    when 0x68 then 0x3F_u8 | @duty << 6
    when 0x69 then read_NRx2
    when 0x6C then 0xFF_u8 # write-only
    when 0x6D then 0xBF_u8 | (@length_enable ? 0x40 : 0)
    else           puts "Reading from invalid Channel2 register: #{hex_str index.to_u16}".colorize.fore(:red); 0_u8 # todo: open bus
    end
  end

  def write_io(index : Int, value : UInt8) : Nil
    case index
    when 0x68
      @duty = (value & 0xC0) >> 6
      @length_load = value & 0x3F
      # Internal values
      @length_counter = 0x40 - @length_load
    when 0x69
      write_NRx2 value
    when 0x6A # not used
    when 0x6B # not used
    when 0x6C
      @frequency = (@frequency & 0x0700) | value
    when 0x6D
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
          @length_counter = 0x40
          # Obscure length counter behavior #2
          @length_counter -= 1 if @length_enable && @gba.apu.first_half_of_length_period
        end
        # Init frequency
        @gba.scheduler.clear Scheduler::EventType::APUChannel2
        schedule_reload frequency_timer
        # Init volume envelope
        init_volume_envelope
      end
    when 0x6E # not used
    when 0x6F # not used
    else raise "Writing to invalid Channel2 register: #{hex_str index.to_u16}"
    end
  end
end
