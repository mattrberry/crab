class PPU
  # Display timings in cycles
  HDRAW    = 960
  HBLANK   = 272
  SCANLINE = HDRAW + HBLANK
  VDRAW    = 160 * SCANLINE
  VBLANK   = 68 * SCANLINE
  REFRESH  = VDRAW + VBLANK

  # LCD Control
  class DISPCNT < BitField(UInt16)
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
    bool reserved_for_bios          # todo update bitfield macro to support overwriting/locking values
    num bg_mode, 3                  # (0-5=Video Mode 0-5, 6-7=Prohibited)
  end

  getter pram = Bytes.new 0x400
  getter vram = Bytes.new 0x18000

  @dispcnt : DISPCNT = DISPCNT.new 0

  @cycles = 0

  def initialize(@gba : GBA)
  end

  def tick(cycles : Int) : Nil
    @cycles += cycles
    if @cycles >= REFRESH
      @gba.display.draw @vram
      @cycles -= REFRESH
    end
  end

  def [](index : Int) : Byte
    case index
    when 0x04000000 then (@dispcnt.value >> 8).to_u8
    when 0x04000001 then @dispcnt.value.to_u8!
    when 0x04000002 then 0_u8
    when 0x04000003 then 0_u8
    else                 raise "Unimplemented PPU read ~ addr:#{hex_str index.to_u32}"
    end
  end

  def []=(index : Int, value : Byte) : Nil
    case index
    when 0x04000000 then @dispcnt.value = (@dispcnt.value & 0x00FF) | value.to_u16 << 8
    when 0x04000001 then @dispcnt.value = (@dispcnt.value & 0xFF00) | value
    when 0x04000002
    when 0x04000003
    else           raise "Unimplemented PPU write ~ addr:#{hex_str index.to_u32}, val:#{value}"
    end
  end
end
