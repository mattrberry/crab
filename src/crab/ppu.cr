class PPU
  BG_OBJ_PALETTE = 0x05000000..0x050003FF
  VRAM           = 0x06000000..0x06017FFF
  OAM            = 0x07000000..0x070003FF

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

  @vram = Bytes.new VRAM.size

  @dispcnt : DISPCNT = DISPCNT.new 0

  def initialize(@gba : GBA)
  end

  def tick(cycles : Int) : Nil
    @gba.display.draw @vram
  end

  def [](index : Int) : Byte
    case index
    when 0x04000000 then (@dispcnt.value >> 8).to_u8
    when 0x04000001 then @dispcnt.value.to_u8!
    when 0x04000002 then 0_u8
    when 0x04000003 then 0_u8
    when VRAM       then @vram[index = VRAM.begin]
    else                 raise "Unimplemented PPU read ~ addr:#{hex_str index.to_u32}"
    end
  end

  def []=(index : Int, value : Byte) : Nil
    case index
    when 0x04000000 then @dispcnt.value = (@dispcnt.value & 0x00FF) | value.to_u16 << 8
    when 0x04000001 then @dispcnt.value = (@dispcnt.value & 0xFF00) | value
    when 0x04000002
    when 0x04000003
    when VRAM then @vram[index - VRAM.begin] = value
    else           raise "Unimplemented PPU write ~ addr:#{hex_str index.to_u32}, val:#{value}"
    end
  end
end
