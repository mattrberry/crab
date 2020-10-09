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

  class DISPSTAT < BitField(UInt16)
    num vcount_setting, 8
    num not_used, 2
    bool vcounter_irq_enable
    bool hblank_irq_enable
    bool vblank_irq_enable
    bool vcounter # todo update bitfield macro to make values read-only when writing to value
    bool hblank   # todo update bitfield macro to make values read-only when writing to value
    bool vblank   # todo update bitfield macro to make values read-only when writing to value
  end

  getter pram = Bytes.new 0x400
  getter vram = Bytes.new 0x18000

  getter dispcnt : DISPCNT = DISPCNT.new 0
  getter dispstat : DISPSTAT = DISPSTAT.new 0

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

  def read_io(io_addr : Int) : Byte
    case io_addr
    when 0x000 then 0xFF_u8 & @dispcnt.value >> 8
    when 0x001 then 0xFF_u8 & @dispcnt.value
    when 0x004 then 0xFF_u8 & @dispstat.value >> 8
    when 0x005 then 0xFF_u8 & @dispstat.value
    else            raise "Unimplemented PPU read ~ addr:#{hex_str io_addr.to_u8}"
    end
  end

  def write_io(io_addr : Int, value : Byte) : Nil
    case io_addr
    when 0x000 then @dispcnt.value = (@dispcnt.value & 0x00FF) | value.to_u16 << 8
    when 0x001 then @dispcnt.value = (@dispcnt.value & 0xFF00) | value
    when 0x002 # undocumented - green swap
    when 0x003 # undocumented - green swap
    when 0x004 then @dispstat.value = (@dispstat.value & 0x00FF) | value.to_u16 << 8
    when 0x005 then @dispstat.value = (@dispstat.value & 0xFF00) | value
    else            raise "Unimplemented PPU write ~ addr:#{hex_str io_addr.to_u8}, val:#{value}"
    end
  end
end
