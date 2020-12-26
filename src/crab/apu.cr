require "./apu/abstract_channels" # so that channels don't need to all import
require "./apu/*"

lib LibSDL
  fun queue_audio = SDL_QueueAudio(dev : AudioDeviceID, data : Void*, len : UInt32) : Int
  fun get_queued_audio_size = SDL_GetQueuedAudioSize(dev : AudioDeviceID) : UInt32
  fun clear_queued_audio = SDL_ClearQueuedAudio(dev : AudioDeviceID)
  fun delay = SDL_Delay(ms : UInt32) : Nil
end

class APU
  CHANNELS      =     2 # Left / Right
  BUFFER_SIZE   =  1024
  SAMPLE_RATE   = 32768 # Hz
  SAMPLE_PERIOD = CPU::CLOCK_SPEED // SAMPLE_RATE

  FRAME_SEQUENCER_RATE   = 512 # Hz
  FRAME_SEQUENCER_PERIOD = CPU::CLOCK_SPEED // FRAME_SEQUENCER_RATE

  @soundcnt_l = Reg::SOUNDCNT_L.new 0
  getter soundcnt_h = Reg::SOUNDCNT_H.new 0
  @sound_enabled : Bool = false
  @soundbias = Reg::SOUNDBIAS.new 0

  @buffer = Slice(Float32).new BUFFER_SIZE
  @buffer_pos = 0
  @frame_sequencer_stage = 0
  getter first_half_of_length_period = false

  @audiospec : LibSDL::AudioSpec
  @obtained_spec : LibSDL::AudioSpec

  def initialize(@gba : GBA)
    @audiospec = LibSDL::AudioSpec.new
    @audiospec.freq = SAMPLE_RATE
    @audiospec.format = LibSDL::AUDIO_F32SYS
    @audiospec.channels = CHANNELS
    @audiospec.samples = BUFFER_SIZE
    @audiospec.callback = nil
    @audiospec.userdata = nil

    @obtained_spec = LibSDL::AudioSpec.new

    @channel1 = Channel1.new @gba
    @channel2 = Channel2.new @gba
    @channel3 = Channel3.new @gba
    @channel4 = Channel4.new @gba
    @dma_channels = DMAChannels.new @gba, @soundcnt_h

    tick_frame_sequencer
    get_sample

    raise "Failed to open audio" if LibSDL.open_audio(pointerof(@audiospec), pointerof(@obtained_spec)) > 0

    LibSDL.pause_audio 0
  end

  def tick_frame_sequencer : Nil
    @first_half_of_length_period = @frame_sequencer_stage & 1 == 0
    case @frame_sequencer_stage
    when 0
      @channel1.length_step
      @channel2.length_step
      @channel3.length_step
      @channel4.length_step
    when 1 then nil
    when 2
      @channel1.length_step
      @channel2.length_step
      @channel3.length_step
      @channel4.length_step
      @channel1.sweep_step
    when 3 then nil
    when 4
      @channel1.length_step
      @channel2.length_step
      @channel3.length_step
      @channel4.length_step
    when 5 then nil
    when 6
      @channel1.length_step
      @channel2.length_step
      @channel3.length_step
      @channel4.length_step
      @channel1.sweep_step
    when 7
      @channel1.volume_step
      @channel2.volume_step
      @channel4.volume_step
    else nil
    end
    @frame_sequencer_stage = 0 if (@frame_sequencer_stage += 1) > 7
    @gba.scheduler.schedule FRAME_SEQUENCER_PERIOD, ->tick_frame_sequencer
  end

  def get_sample : Nil
    channel1_amp = @channel1.get_amplitude
    channel2_amp = @channel2.get_amplitude
    channel3_amp = @channel3.get_amplitude
    channel4_amp = @channel4.get_amplitude
    dma_amp = @dma_channels.get_amplitude
    @buffer[@buffer_pos] = (@soundcnt_l.left_volume / 7).to_f32 *
                           ((channel4_amp * @soundcnt_l.channel_4_left) +
                            (channel3_amp * @soundcnt_l.channel_3_left) +
                            (channel2_amp * @soundcnt_l.channel_2_left) +
                            (channel1_amp * @soundcnt_l.channel_1_left) +
                            (dma_amp)) / 5
    @buffer[@buffer_pos + 1] = (@soundcnt_l.right_volume).to_f32 *
                               ((channel4_amp * @soundcnt_l.channel_4_right) +
                                (channel3_amp * @soundcnt_l.channel_3_right) +
                                (channel2_amp * @soundcnt_l.channel_2_right) +
                                (channel1_amp * @soundcnt_l.channel_1_right) +
                                (dma_amp)) / 5
    abort @buffer[@buffer_pos] if @buffer[@buffer_pos].abs > 1
    @buffer_pos += 2

    # push to SDL if buffer is full
    if @buffer_pos >= BUFFER_SIZE
      while LibSDL.get_queued_audio_size(1) > BUFFER_SIZE * sizeof(Float32) * 2
        LibSDL.delay(1)
      end
      LibSDL.queue_audio 1, @buffer, BUFFER_SIZE * sizeof(Float32)
      @buffer_pos = 0
    end

    @gba.scheduler.schedule SAMPLE_PERIOD, ->get_sample
  end

  def timer_overflow(timer : Int) : Nil
    @dma_channels.timer_overflow timer
  end

  def read_io(io_addr : Int) : UInt8
    case io_addr
    when @channel1     then @channel1.read_io io_addr
    when @channel2     then @channel2.read_io io_addr
    when @channel3     then @channel3.read_io io_addr
    when @channel4     then @channel4.read_io io_addr
    when @dma_channels then @dma_channels.read_io io_addr
    when 0x80          then @soundcnt_l.value.to_u8!
    when 0x81          then (@soundcnt_l.value >> 8).to_u8!
    when 0x82          then @soundcnt_h.value.to_u8!
    when 0x83          then (@soundcnt_h.value >> 8).to_u8!
    when 0x84
      0x70_u8 |
        (@sound_enabled ? 0x80 : 0) |
        (@channel4.enabled ? 0b1000 : 0) |
        (@channel3.enabled ? 0b0100 : 0) |
        (@channel2.enabled ? 0b0010 : 0) |
        (@channel1.enabled ? 0b0001 : 0)
    when 0x85 then 0_u8 # unused
    when 0x88 then @soundbias.value.to_u8!
    when 0x89 then (@soundbias.value >> 8).to_u8!
    else           abort "Unmapped APU read ~ addr:#{hex_str io_addr.to_u8}"
    end
  end

  # write to apu memory
  def write_io(io_addr : Int, value : UInt8) : Nil
    return unless @sound_enabled || io_addr == 0x84 || Channel3::WAVE_RAM_RANGE.includes?(io_addr)
    case io_addr
    when @channel1     then @channel1.write_io io_addr, value
    when @channel2     then @channel2.write_io io_addr, value
    when @channel3     then @channel3.write_io io_addr, value
    when @channel4     then @channel4.write_io io_addr, value
    when @dma_channels then @dma_channels.write_io io_addr, value
    when 0x80          then @soundcnt_l.value = (@soundcnt_l.value & 0xFF00) | value
    when 0x81          then @soundcnt_l.value = (@soundcnt_l.value & 0x00FF) | value.to_u16 << 8
    when 0x82          then @soundcnt_h.value = (@soundcnt_h.value & 0xFF00) | value
    when 0x83          then @soundcnt_h.value = (@soundcnt_h.value & 0x00FF) | value.to_u16 << 8
    when 0x84
      if value & 0x80 == 0 && @sound_enabled
        (0xFF10..0xFF25).each { |addr| self.write_io addr, 0x00 }
        @sound_enabled = false
      elsif value & 0x80 > 0 && !@sound_enabled
        @sound_enabled = true
        @frame_sequencer_stage = 0
        @channel1.length_counter = 0
        @channel2.length_counter = 0
        @channel3.length_counter = 0
        @channel4.length_counter = 0
      end
    when 0x85 # unused
    when 0x88 then @soundbias.value = (@soundbias.value & 0xFF00) | value
    when 0x89 then @soundbias.value = (@soundbias.value & 0x00FF) | value.to_u16 << 8
    else           puts "Unmapped APU write ~ addr:#{hex_str io_addr.to_u8}, val:#{value}".colorize(:yellow)
    end

    puts "SOUNDCNT_H(vol:#{@soundcnt_h.sound_volume}, a_vol:#{@soundcnt_h.dma_sound_a_volume}, b_vol:#{@soundcnt_h.dma_sound_b_volume}, a_right:#{@soundcnt_h.dma_sound_a_right}, a_left:#{@soundcnt_h.dma_sound_a_left}, a_timer:#{@soundcnt_h.dma_sound_a_timer}, b_right:#{@soundcnt_h.dma_sound_b_right}, b_left:#{@soundcnt_h.dma_sound_b_left}, b_timer:#{@soundcnt_h.dma_sound_b_timer}".colorize.fore(:blue) if 0x82 <= io_addr <= 0x83
  end
end
