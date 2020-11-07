class PPU
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
    bool reserved_for_bios, lock: true
    num bg_mode, 3 # (0-5=Video Mode 0-5, 6-7=Prohibited)
  end

  class DISPSTAT < BitField(UInt16)
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
    num screen_size, 2
    bool screen_overflow
    num tile_map, 5
    bool colors_palette
    bool mosaic
    num not_used, 2, lock: true
    num tile_data, 2
    num priority, 2
  end

  @framebuffer : Bytes = Bytes.new 0x12C00 # framebuffer as 16-bit xBBBBBGGGGGRRRRR

  getter pram = Bytes.new 0x400
  getter vram = Bytes.new 0x18000
  getter oam = Bytes.new 0x400

  getter dispcnt : DISPCNT = DISPCNT.new 0
  getter dispstat : DISPSTAT = DISPSTAT.new 0
  getter vcount : UInt16 = 0x0000_u16
  getter bg0cnt : BGCNT = BGCNT.new 0
  getter bg1cnt : BGCNT = BGCNT.new 0
  getter bg2cnt : BGCNT = BGCNT.new 0
  getter bg3cnt : BGCNT = BGCNT.new 0

  def initialize(@gba : GBA)
    start_line
  end

  def start_line : Nil
    @gba.scheduler.schedule 960, ->start_hblank
  end

  def start_hblank : Nil
    @gba.scheduler.schedule 272, ->end_hblank
    @dispstat.hblank = true
    scanline if @vcount < 160
  end

  def end_hblank : Nil
    @dispstat.hblank = false
    @vcount += 1
    @vcount %= 228
    if @vcount == 0
      @dispstat.vblank = false
    elsif @vcount == 160
      @dispstat.vblank = true
      draw
    end
    @gba.scheduler.schedule 0, ->start_line
  end

  def draw : Nil
    @gba.display.draw @framebuffer
  end

  def scanline : Nil
    case @dispcnt.bg_mode
    when 0, 1, 2
      puts "Unsupported background mode: #{@dispcnt.bg_mode}"
    when 3
      240.times do |col|
        row_base = 240 * 2 * @vcount
        @framebuffer[row_base + col * 2] = @vram[row_base + col * 2]
        @framebuffer[row_base + col * 2 + 1] = @vram[row_base + col * 2 + 1]
      end
    when 4
      base = @dispcnt.display_frame_select ? 0xA000 : 0
      240.times do |col|
        idx = 240 * @vcount + col
        pal_idx = @vram[base + idx]
        @framebuffer[idx * 2] = @pram[pal_idx * 2]
        @framebuffer[idx * 2 + 1] = @pram[pal_idx * 2 + 1]
      end
    when 5
      base = @dispcnt.display_frame_select ? 0xA000 : 0
      if @vcount < 128
        160.times do |col|
          @framebuffer[(240 * @vcount + col) * 2] = @vram[base + (@vcount * 160 + col) * 2]
          @framebuffer[(240 * @vcount + col) * 2 + 1] = @vram[base + (@vcount * 160 + col) * 2 + 1]
        end
        160.to 239 do |col|
          @framebuffer[(240 * @vcount + col) * 2] = 0x1F
          @framebuffer[(240 * @vcount + col) * 2 + 1] = 0x7C
        end
      else
        240.times do |col|
          @framebuffer[(240 * @vcount + col) * 2] = 0x1F
          @framebuffer[(240 * @vcount + col) * 2 + 1] = 0x7C
        end
      end
    else abort "Invalid background mode: #{@dispcnt.bg_mode}"
    end
  end

  def read_io(io_addr : Int) : Byte
    case io_addr
    when 0x000 then 0xFF_u8 & @dispcnt.value
    when 0x001 then 0xFF_u8 & @dispcnt.value >> 8
    when 0x002 then 0xFF_u8 # todo green swap
    when 0x003 then 0xFF_u8 # todo green swap
    when 0x004 then 0xFF_u8 & @dispstat.value
    when 0x005 then 0xFF_u8 & @dispstat.value >> 8
    when 0x006 then 0xFF_u8 & @vcount
    when 0x007 then 0xFF_u8 & @vcount >> 8
    when 0x008 then 0xFF_u8 & @bg0cnt.value
    when 0x009 then 0xFF_u8 & @bg0cnt.value >> 8
    when 0x00A then 0xFF_u8 & @bg1cnt.value
    when 0x00B then 0xFF_u8 & @bg1cnt.value >> 8
    when 0x00C then 0xFF_u8 & @bg2cnt.value
    when 0x00D then 0xFF_u8 & @bg2cnt.value >> 8
    when 0x00E then 0xFF_u8 & @bg3cnt.value
    when 0x00F then 0xFF_u8 & @bg3cnt.value >> 8
    else            raise "Unimplemented PPU read ~ addr:#{hex_str io_addr.to_u8}"
    end
  end

  def write_io(io_addr : Int, value : Byte) : Nil
    case io_addr
    when 0x000 then @dispcnt.value = (@dispcnt.value & 0xFF00) | value
    when 0x001 then @dispcnt.value = (@dispcnt.value & 0x00FF) | value.to_u16 << 8
    when 0x002 # undocumented - green swap
    when 0x003 # undocumented - green swap
    when 0x004 then @dispstat.value = (@dispstat.value & 0xFF00) | value
    when 0x005 then @dispstat.value = (@dispstat.value & 0x00FF) | value.to_u16 << 8
    when 0x008 then @bg0cnt.value = (@bg0cnt.value & 0xFF00) | value
    when 0x009 then @bg0cnt.value = (@bg0cnt.value & 0x00FF) | value.to_u16 << 8
    when 0x00A then @bg1cnt.value = (@bg1cnt.value & 0xFF00) | value
    when 0x00B then @bg1cnt.value = (@bg1cnt.value & 0x00FF) | value.to_u16 << 8
    when 0x00C then @bg2cnt.value = (@bg2cnt.value & 0xFF00) | value
    when 0x00D then @bg2cnt.value = (@bg2cnt.value & 0x00FF) | value.to_u16 << 8
    when 0x00E then @bg3cnt.value = (@bg3cnt.value & 0xFF00) | value
    when 0x00F then @bg3cnt.value = (@bg3cnt.value & 0x00FF) | value.to_u16 << 8
    else            raise "Unimplemented PPU write ~ addr:#{hex_str io_addr.to_u8}, val:#{value}"
    end
  end
end
