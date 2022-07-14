# All of the channels were developed using the following guide on gbdev
# https://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware

module GBA
  abstract class SoundChannel
    property enabled : Bool = false
    @dac_enabled : Bool = false

    # NRx1
    property length_counter = 0

    # NRx4
    @length_enable : Bool = false

    def initialize(@gba : GBA)
    end

    # Step the channel, calling helpers to reload the period and step the wave generation
    def step : Nil
      step_wave_generation
      schedule_reload frequency_timer
    end

    # Step the length, disabling the channel if the length counter expires
    def length_step : Nil
      if @length_enable && @length_counter > 0
        @length_counter -= 1
        @enabled = false if @length_counter == 0
      end
    end

    # Used so that channels can be matched with case..when statements
    abstract def ===(other)

    # Calculate the frequency timer
    abstract def frequency_timer : UInt32

    abstract def schedule_reload(frequency_timer : UInt32) : Nil

    # Called when @period reaches 0
    abstract def step_wave_generation : Nil

    abstract def get_amplitude : Int16

    abstract def read_io(index : Int) : UInt8
    abstract def write_io(index : Int, value : UInt8) : Nil
  end

  abstract class VolumeEnvelopeChannel < SoundChannel
    # NRx2
    @starting_volume : UInt8 = 0x00
    @envelope_add_mode : Bool = false
    @period : UInt8 = 0x00

    @volume_envelope_timer : UInt8 = 0x00
    @current_volume : UInt8 = 0x00

    @volume_envelope_is_updating = false

    def volume_step : Nil
      if @period != 0
        @volume_envelope_timer -= 1 if @volume_envelope_timer > 0
        if @volume_envelope_timer == 0
          @volume_envelope_timer = @period
          if (@current_volume < 0xF && @envelope_add_mode) || (@current_volume > 0 && !@envelope_add_mode)
            @current_volume += (@envelope_add_mode ? 1 : -1)
          else
            @volume_envelope_is_updating = false
          end
        end
      end
    end

    def init_volume_envelope : Nil
      @volume_envelope_timer = @period
      @current_volume = @starting_volume
      @volume_envelope_is_updating = true
    end

    def read_NRx2 : UInt8
      @starting_volume << 4 | (@envelope_add_mode ? 0x08 : 0) | @period
    end

    def write_NRx2(value : UInt8) : Nil
      envelope_add_mode = value & 0x08 > 0
      if @enabled # Zombie mode glitch
        @current_volume += 1 if (@period == 0 && @volume_envelope_is_updating) || !@envelope_add_mode
        @current_volume = 0x10_u8 - @current_volume if (envelope_add_mode != @envelope_add_mode)
        @current_volume &= 0x0F
      end

      @starting_volume = value >> 4
      @envelope_add_mode = envelope_add_mode
      @period = value & 0x07
      # Internal values
      @dac_enabled = value & 0xF8 > 0
      @enabled = false if !@dac_enabled
    end
  end
end
