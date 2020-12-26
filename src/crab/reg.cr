module Reg
  ####################
  # APU

  class SOUNDCNT_L < BitField(UInt16)
    num channel_4_left, 1
    num channel_3_left, 1
    num channel_2_left, 1
    num channel_1_left, 1
    num channel_4_right, 1
    num channel_3_right, 1
    num channel_2_right, 1
    num channel_1_right, 1
    bool not_used_1, lock: true
    num left_volume, 3
    bool not_used_2, lock: true
    num right_volume, 3
  end

  class SOUNDCNT_H < BitField(UInt16)
    bool dma_sound_b_reset, lock: true
    num dma_sound_b_timer, 1
    bool dma_sound_b_left
    bool dma_sound_b_right
    bool dma_sound_a_reset, lock: true
    num dma_sound_a_timer, 1
    bool dma_sound_a_left
    bool dma_sound_a_right
    num not_used, 4, lock: true
    bool dma_sound_b_volume
    bool dma_sound_a_volume
    num sound_volume, 2
  end

  class SOUNDBIAS < BitField(UInt16)
    num amplitude_resolution, 2
    num not_used_1, 4
    num bias_level, 9
    bool not_used_2
  end
end
