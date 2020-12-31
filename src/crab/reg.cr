module Reg
  module Base16
    def read_byte(byte_num : Int) : Byte
      (@value >> (8 * byte_num)).to_u8!
    end

    def write_byte(byte_num : Int, byte : Byte) : Byte
      shift = 8 * byte_num
      mask = ~(0xFF_u16 << shift)
      @value = (@value & mask) | byte.to_u16 << shift
      byte
    end
  end

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
    num dma_sound_b_left, 1
    num dma_sound_b_right, 1
    bool dma_sound_a_reset, lock: true
    num dma_sound_a_timer, 1
    num dma_sound_a_left, 1
    num dma_sound_a_right, 1
    num not_used, 4, lock: true
    num dma_sound_b_volume, 1
    num dma_sound_a_volume, 1
    num sound_volume, 2
  end

  class SOUNDBIAS < BitField(UInt16)
    num amplitude_resolution, 2
    num not_used_1, 4
    num bias_level, 9
    bool not_used_2
  end

  ####################
  # PPU

  class DISPCNT < BitField(UInt16)
    include Base16
    bool obj_window_display
    bool window_1_display
    bool window_0_display
    bool screen_display_obj
    bool screen_display_bg3
    bool screen_display_bg2
    bool screen_display_bg1
    bool screen_display_bg0
    bool forced_blank               # (1=Allow access to VRAM,Palette,OAM)
    bool obj_character_vram_mapping # (0=Two dimensional, 1=One dimensional)
    bool hblank_interval_free       # (1=Allow access to OAM during H-Blank)
    bool display_frame_select       # (0-1=Frame 0-1) (for BG Modes 4,5 only)
    bool reserved_for_bios, lock: true
    num bg_mode, 3 # (0-5=Video Mode 0-5, 6-7=Prohibited)
  end

  class DISPSTAT < BitField(UInt16)
    include Base16
    num vcount_setting, 8
    num not_used, 2
    bool vcounter_irq_enable
    bool hblank_irq_enable
    bool vblank_irq_enable
    bool vcounter, lock: true
    bool hblank, lock: true
    bool vblank, lock: true
  end

  class BGCNT < BitField(UInt16)
    include Base16
    num screen_size, 2
    bool affine_wrap
    num screen_base_block, 5
    bool color_mode
    bool mosaic
    num not_used, 2, lock: true
    num character_base_block, 2
    num priority, 2
  end

  class BGOFS < BitField(UInt16)
    include Base16
    num not_used, 7, lock: true
    num offset, 9
  end

  class WINH < BitField(UInt16)
    include Base16
    num x1, 8
    num x2, 8
  end

  class WINV < BitField(UInt16)
    include Base16
    num y1, 8
    num y2, 8
  end

  class WININ < BitField(UInt16)
    include Base16
    num not_used_1, 2, lock: true
    bool window_1_color_special_effect
    bool window_1_obj_enable
    num window_1_enable_bits, 4
    num not_used_0, 2, lock: true
    bool window_0_color_special_effect
    bool window_0_obj_enable
    num window_0_enable_bits, 4
  end

  class WINOUT < BitField(UInt16)
    include Base16
    num not_used_obj, 2, lock: true
    bool obj_window_color_special_effect
    bool obj_window_obj_enable
    num obj_window_enable_bits, 4
    num not_used_outside, 2, lock: true
    bool outside_color_special_effect
    bool outside_obj_enable
    num outside_enable_bits, 4
  end

  class MOSAIC < BitField(UInt16)
    include Base16
    num obj_mosiac_v_size, 4
    num obj_mosiac_h_size, 4
    num bg_mosiac_v_size, 4
    num bg_mosiac_h_size, 4
  end

  class BLDCNT < BitField(UInt16)
    include Base16
    num not_used, 2, lock: true
    bool bd_2nd_target_pixel
    bool obj_2nd_target_pixel
    bool bg3_2nd_target_pixel
    bool bg2_2nd_target_pixel
    bool bg1_2nd_target_pixel
    bool bg0_2nd_target_pixel
    num color_special_effect, 2
    bool bd_1st_target_pixel
    bool obj_1st_target_pixel
    bool bg3_1st_target_pixel
    bool bg2_1st_target_pixel
    bool bg1_1st_target_pixel
    bool bg0_1st_target_pixel
  end

  class BLDALPHA < BitField(UInt16)
    include Base16
    num not_used_13_15, 3, lock: true
    num evb_coefficient, 5
    num not_used_5_7, 3, lock: true
    num eva_coefficient, 5
  end

  class BLDY < BitField(UInt16)
    include Base16
    num not_used, 11, lock: true
    num evy_coefficient, 5
  end
end
