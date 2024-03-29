module GBA
  module Reg
    module Base16
      def read_byte(byte_num : Int) : UInt8
        (value >> (8 * byte_num)).to_u8!
      end

      def write_byte(byte_num : Int, byte : UInt8) : UInt8
        shift = 8 * byte_num
        mask = ~(0xFF_u16 << shift)
        self.value = (@value & mask) | byte.to_u16 << shift
        byte
      end
    end

    module Base32
      def read_byte(byte_num : Int) : UInt8
        (value >> (8 * byte_num)).to_u8!
      end

      def write_byte(byte_num : Int, byte : UInt8) : UInt8
        shift = 8 * byte_num
        mask = ~(0xFF_u32 << shift)
        self.value = (@value & mask) | byte.to_u32 << shift
        byte
      end
    end

    ####################
    # General

    class WAITCNT < BitField(UInt16)
      include Base16
      num sram_wait_control, 2
      num wait_state_0_first_access, 2
      num wait_state_0_second_access, 1
      num wait_state_1_first_access, 2
      num wait_state_1_second_access, 1
      num wait_state_2_first_access, 2
      num wait_state_2_second_access, 1
      num phi_terminal_output, 2
      bool not_used, read_only: true
      bool gamepack_prefetch_buffer
      bool gamepak_type, read_only: true
    end

    ####################
    # Interrupts

    class InterruptReg < BitField(UInt16)
      bool vblank
      bool hblank
      bool vcounter
      bool timer0
      bool timer1
      bool timer2
      bool timer3
      bool serial
      bool dma0
      bool dma1
      bool dma2
      bool dma3
      bool keypad
      bool game_pak
      num not_used, 2, read_only: true
    end

    ####################
    # APU

    class SOUNDCNT_L < BitField(UInt16)
      num right_volume, 3
      bool not_used_2, read_only: true
      num left_volume, 3
      bool not_used_1, read_only: true
      num channel_1_right, 1
      num channel_2_right, 1
      num channel_3_right, 1
      num channel_4_right, 1
      num channel_1_left, 1
      num channel_2_left, 1
      num channel_3_left, 1
      num channel_4_left, 1
    end

    class SOUNDCNT_H < BitField(UInt16)
      num sound_volume, 2
      num dma_sound_a_volume, 1
      num dma_sound_b_volume, 1
      num not_used, 4, read_only: true
      num dma_sound_a_right, 1
      num dma_sound_a_left, 1
      num dma_sound_a_timer, 1
      bool dma_sound_a_reset, read_only: true
      num dma_sound_b_right, 1
      num dma_sound_b_left, 1
      num dma_sound_b_timer, 1
      bool dma_sound_b_reset, read_only: true
    end

    class SOUNDBIAS < BitField(UInt16)
      bool not_used_2
      num bias_level, 9
      num not_used_1, 4
      num amplitude_resolution, 2
    end

    ####################
    # DMA

    class DMACNT < BitField(UInt16)
      include Base16
      num not_used, 5, read_only: true
      num dest_control, 2
      num source_control, 2
      bool repeat
      num type, 1
      bool game_pak, write_only: true # special dma3 case handled separately
      num start_timing, 2
      bool irq_enable
      bool enable
    end

    ####################
    # Timer

    class TMCNT < BitField(UInt16)
      num frequency, 2
      bool cascade
      num not_used_2, 3, read_only: true
      bool irq_enable
      bool enable
      num not_used_1, 8, read_only: true
    end

    ####################
    # PPU

    class DISPCNT < BitField(UInt16)
      include Base16
      num bg_mode, 3 # (0-5=Video Mode 0-5, 6-7=Prohibited)
      bool reserved_for_bios, read_only: true
      bool display_frame_select # (0-1=Frame 0-1) (for BG Modes 4,5 only)
      bool hblank_interval_free # (1=Allow access to OAM during H-Blank)
      bool obj_mapping_1d       # (0=Two dimensional, 1=One dimensional)
      bool forced_blank         # (1=Allow access to VRAM,Palette,OAM)
      num default_enable_bits, 5
      bool window_0_display
      bool window_1_display
      bool obj_window_display
    end

    class DISPSTAT < BitField(UInt16)
      include Base16
      bool vblank, read_only: true
      bool hblank, read_only: true
      bool vcounter, read_only: true
      bool vblank_irq_enable
      bool hblank_irq_enable
      bool vcounter_irq_enable
      num not_used, 2
      num vcount_setting, 8
    end

    class BGCNT < BitField(UInt16)
      include Base16
      num priority, 2
      num character_base_block, 2
      num not_used, 2
      bool mosaic
      bool color_mode_8bpp
      num screen_base_block, 5
      bool affine_wrap, write_only: true # used only in bg2 and bg3
      num screen_size, 2
    end

    class BGOFS < BitField(UInt16)
      include Base16
      num offset, 9
      num not_used, 7, read_only: true
    end

    class BGAFF < BitField(UInt16)
      include Base16
      num fraction, 8
      num integer, 7
      bool sign

      def num : Int16
        value.to_i16!
      end
    end

    class BGREF < BitField(UInt32)
      include Base32
      num fraction, 8
      num integer, 19
      bool sign
      num not_used, 4, read_only: true

      def num : Int32
        (value << 4).to_i32! >> 4
      end
    end

    class WINH < BitField(UInt16)
      include Base16
      num x2, 8
      num x1, 8
    end

    class WINV < BitField(UInt16)
      include Base16
      num y2, 8
      num y1, 8
    end

    class WININ < BitField(UInt16)
      include Base16
      num window_0_enable_bits, 5
      bool window_0_color_special_effect
      num not_used_0, 2, read_only: true
      num window_1_enable_bits, 5
      bool window_1_color_special_effect
      num not_used_1, 2, read_only: true
    end

    class WINOUT < BitField(UInt16)
      include Base16
      num outside_enable_bits, 5
      bool outside_color_special_effect
      num not_used_outside, 2, read_only: true
      num obj_window_enable_bits, 5
      bool obj_window_color_special_effect
      num not_used_obj, 2, read_only: true
    end

    class MOSAIC < BitField(UInt16)
      include Base16
      num bg_mosiac_h_size, 4
      num bg_mosiac_v_size, 4
      num obj_mosiac_h_size, 4
      num obj_mosiac_v_size, 4
    end

    class BLDCNT < BitField(UInt16)
      include Base16
      bool bg0_1st_target_pixel
      bool bg1_1st_target_pixel
      bool bg2_1st_target_pixel
      bool bg3_1st_target_pixel
      bool obj_1st_target_pixel
      bool bd_1st_target_pixel
      num blend_mode, 2
      bool bg0_2nd_target_pixel
      bool bg1_2nd_target_pixel
      bool bg2_2nd_target_pixel
      bool bg3_2nd_target_pixel
      bool obj_2nd_target_pixel
      bool bd_2nd_target_pixel
      num not_used, 2, read_only: true

      def layer_target?(layer : Int, target : Int) : Bool
        bit?(value, layer + ((target - 1) * 8))
      end
    end

    class BLDALPHA < BitField(UInt16)
      include Base16
      num eva_coefficient, 5
      num not_used_5_7, 3, read_only: true
      num evb_coefficient, 5
      num not_used_13_15, 3, read_only: true
    end

    class BLDY < BitField(UInt16)
      include Base16
      num evy_coefficient, 5
      num not_used, 11, read_only: true
    end

    ####################
    # Keypad

    class KEYINPUT < BitField(UInt16)
      include Base16
      bool a
      bool b
      bool :select
      bool start
      bool right
      bool left
      bool up
      bool down
      bool r
      bool l
      num not_used, 6
    end

    class KEYCNT < BitField(UInt16)
      include Base16
      bool a
      bool b
      bool :select
      bool start
      bool right
      bool left
      bool up
      bool down
      bool r
      bool l
      num not_used, 4
      bool irq_enable
      bool irq_condition
    end
  end
end
