class Channel1 < VolumeEnvelopeChannel
  WAVE_DUTY = [
    [0, 0, 0, 0, 0, 0, 0, 1], # 12.5%
    [1, 0, 0, 0, 0, 0, 0, 1], # 25%
    [1, 0, 0, 0, 0, 1, 1, 1], # 50%
    [0, 1, 1, 1, 1, 1, 1, 0], # 75%
  ]

  RANGE = 0x60..0x67

  def ===(value) : Bool
    value.is_a?(Int) && RANGE.includes?(value)
  end

  @wave_duty_position = 0

  # NR10
  @sweep_period : UInt8 = 0x00
  @negate : Bool = false
  @shift : UInt8 = 0x00

  @sweep_timer : UInt8 = 0x00
  @frequency_shadow : UInt16 = 0x0000
  @sweep_enabled : Bool = false
  @negate_has_been_used : Bool = false

  # NR11
  @duty : UInt8 = 0x00
  @length_load : UInt8 = 0x00

  # NR13 / NR14
  @frequency : UInt16 = 0x00

  def step_wave_generation : Nil
    @wave_duty_position = (@wave_duty_position + 1) & 7
  end

  def frequency_timer : UInt32
    (0x800_u32 - @frequency) * 4 * 4
  end

  def schedule_reload(frequency_timer : UInt32) : Nil
    @gba.scheduler.schedule frequency_timer, ->step, Scheduler::EventType::APUChannel1
  end

  def sweep_step : Nil
    @sweep_timer -= 1 if @sweep_timer > 0
    if @sweep_timer == 0
      @sweep_timer = @sweep_period > 0 ? @sweep_period : 8_u8
      if @sweep_enabled && @sweep_period > 0
        calculated = frequency_calculation
        if calculated <= 0x07FF && @shift > 0
          @frequency_shadow = @frequency = calculated
          frequency_calculation
        end
      end
    end
  end

  # Outputs a value 0..0xF
  def get_amplitude : Int16
    if @enabled && @dac_enabled
      WAVE_DUTY[@duty][@wave_duty_position].to_i16 * @current_volume
    else
      0_i16
    end
  end

  # Calculate the new shadow frequency, disable channel if overflow 11 bits
  # https://gist.github.com/drhelius/3652407#file-game-boy-sound-operation-L243-L250
  def frequency_calculation : UInt16
    calculated = @frequency_shadow >> @shift
    calculated = @frequency_shadow + (@negate ? -1 : 1) * calculated
    @negate_has_been_used = true if @negate
    @enabled = false if calculated > 0x07FF
    calculated
  end

  def read_io(index : Int) : UInt8
    case index
    when 0x60 then 0x80_u8 | @sweep_period << 4 | (@negate ? 0x08 : 0) | @shift
    when 0x62 then 0x3F_u8 | @duty << 6
    when 0x63 then read_NRx2
    when 0x64 then 0xFF_u8 # write-only
    when 0x65 then 0xBF_u8 | (@length_enable ? 0x40 : 0)
    else           raise "Reading from invalid Channel1 register: #{hex_str index.to_u16}"
    end
  end

  def write_io(index : Int, value : UInt8) : Nil
    case index
    when 0x60
      @sweep_period = (value & 0x70) >> 4
      @negate = value & 0x08 > 0
      @shift = value & 0x07
      # Internal values
      @enabled = false if !@negate && @negate_has_been_used
    when 0x61 # not used
    when 0x62
      @duty = (value & 0xC0) >> 6
      @length_load = value & 0x3F
      # Internal values
      @length_counter = 0x40 - @length_load
    when 0x63
      write_NRx2 value
    when 0x64
      @frequency = (@frequency & 0x0700) | value
    when 0x65
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
        @gba.scheduler.clear Scheduler::EventType::APUChannel1
        schedule_reload frequency_timer
        # Init volume envelope
        init_volume_envelope
        # Init sweep
        @frequency_shadow = @frequency
        @sweep_timer = @sweep_period > 0 ? @sweep_period : 8_u8
        @sweep_enabled = @sweep_period > 0 || @shift > 0
        @negate_has_been_used = false
        if @shift > 0 # If sweep shift is non-zero, frequency calculation and overflow check are performed immediately
          frequency_calculation
        end
      end
    else raise "Writing to invalid Channel1 register: #{hex_str index.to_u16}"
    end
  end
end
