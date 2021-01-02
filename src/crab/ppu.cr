class PPU
  @framebuffer : Slice(UInt16) = Slice(UInt16).new 0x9600 # framebuffer as 16-bit xBBBBBGGGGGRRRRR

  getter pram = Bytes.new 0x400
  getter vram = Bytes.new 0x18000
  getter oam = Bytes.new 0x400

  getter dispcnt = Reg::DISPCNT.new 0
  getter dispstat = Reg::DISPSTAT.new 0
  getter vcount : UInt16 = 0x0000_u16
  getter bgcnt = Array(Reg::BGCNT).new 4 { Reg::BGCNT.new 0 }
  getter bghofs = Array(Reg::BGOFS).new 4 { Reg::BGOFS.new 0 }
  getter bgvofs = Array(Reg::BGOFS).new 4 { Reg::BGOFS.new 0 }
  getter win0h = Reg::WINH.new 0
  getter win1h = Reg::WINH.new 0
  getter win0V = Reg::WINV.new 0
  getter win1V = Reg::WINV.new 0
  getter winin = Reg::WININ.new 0
  getter winout = Reg::WINOUT.new 0
  getter mosaic = Reg::MOSAIC.new 0
  getter bldcnt = Reg::BLDCNT.new 0
  getter bldalpha = Reg::BLDALPHA.new 0
  getter bldy = Reg::BLDY.new 0

  def initialize(@gba : GBA)
    start_line
  end

  def start_line : Nil
    @gba.scheduler.schedule 960, ->start_hblank
  end

  def start_hblank : Nil
    @gba.scheduler.schedule 272, ->end_hblank
    @dispstat.hblank = true
    @gba.interrupts.reg_if.hblank = @dispstat.hblank_irq_enable
    @gba.interrupts.schedule_interrupt_check if @dispstat.hblank_irq_enable
    scanline if @vcount < 160
  end

  def end_hblank : Nil
    @dispstat.hblank = false
    @gba.interrupts.reg_if.hblank = false
    @vcount = (@vcount + 1) % 228
    @dispstat.vcounter = @vcount == @dispstat.vcount_setting
    @gba.interrupts.reg_if.vcounter = @dispstat.vcounter_irq_enable && @dispstat.vcounter
    if @vcount == 0
      @dispstat.vblank = false
      @gba.interrupts.reg_if.vblank = false
    elsif @vcount == 160
      @dispstat.vblank = true
      @gba.interrupts.reg_if.vblank = @dispstat.vblank_irq_enable
      draw
    end
    @gba.interrupts.schedule_interrupt_check
    @gba.scheduler.schedule 0, ->start_line
  end

  def draw : Nil
    @gba.display.draw @framebuffer
  end

  # Get the screen entry offset from the tile x, tile y, and background screen-size param using tonc algo
  @[AlwaysInline]
  def se_index(tx : Int, ty : Int, screen_size : Int) : Int
    n = tx + ty * 32
    n += 0x03E0 if tx >= 32
    n += 0x0400 if ty >= 32 && screen_size == 0b11
    n
  end

  def scanline : Nil
    row = @vcount.to_u32
    row_base = 240 * row
    scanline = @framebuffer + row_base
    scanline.to_unsafe.clear(240)
    case @dispcnt.bg_mode
    when 0
      4.times do |priority|
        4.times do |bg|
          render_background(scanline, row, bg) if @bgcnt[bg].priority == priority
        end
      end
    when 1, 2
      puts "Unsupported background mode: #{@dispcnt.bg_mode}"
    when 3
      240.times do |col|
        idx = row_base + col
        scanline[col] = @vram.to_unsafe.as(UInt16*)[idx]
      end
    when 4
      base = @dispcnt.display_frame_select ? 0xA000 : 0
      240.times do |col|
        pal_idx = @vram[base + row_base + col]
        scanline[col] = @pram.to_unsafe.as(UInt16*)[pal_idx]
      end
    when 5
      base = @dispcnt.display_frame_select ? 0xA000 : 0
      background_color = @pram.to_unsafe.as(UInt16*)[0]
      if @vcount < 128
        160.times do |col|
          scanline[col] = (@vram + base).to_unsafe.as(UInt16*)[row * 160 + col]
        end
        160.to 239 do |col|
          scanline[col] = background_color
        end
      else
        240.times do |col|
          scanline[col] = background_color
        end
      end
    else abort "Invalid background mode: #{@dispcnt.bg_mode}"
    end
  end

  def render_background(scanline : Slice(UInt16), row : Int, bg : Int) : Nil
    # todo handle all bg layers
    tw, th = case @bgcnt[bg].screen_size
             when 0b00 then {32, 32} # 32x32
             when 0b01 then {64, 32} # 64x32
             when 0b10 then {32, 64} # 32x64
             when 0b11 then {64, 64} # 64x64
             else           raise "Impossible bgcnt screen size: #{@bgcnt[bg].screen_size}"
             end
    # todo actually handle different sizes

    screen_base = 0x800_u32 * @bgcnt[bg].screen_base_block
    character_base = @bgcnt[bg].character_base_block * 0x4000
    effective_row = (row + @bgvofs[bg].value) % (th << 3)
    ty = effective_row >> 3
    240.times do |col|
      next if scanline[col] > 0

      effective_col = (col + @bghofs[bg].value) % (tw << 3)
      tx = effective_col >> 3

      se_idx = se_index(tx, ty, @bgcnt[bg].screen_size)
      screen_entry = @vram[screen_base + se_idx * 2 + 1].to_u16 << 8 | @vram[screen_base + se_idx * 2]

      tile_id = bits(screen_entry, 0..9)
      palette_bank = bits(screen_entry, 12..15)
      y = (effective_row & 7) ^ (7 * (screen_entry >> 11 & 1))
      x = (effective_col & 7) ^ (7 * (screen_entry >> 10 & 1))

      if @bgcnt[bg].color_mode # 8bpp
        abort "todo 8bpp"
      else # 4bpp
        palettes = @vram[character_base + tile_id * 0x20 + y * 4 + (x >> 1)]
        pal_idx = (palette_bank << 4) + ((palettes >> ((x & 1) * 4)) & 0xF)
      end
      scanline[col] = @pram.to_unsafe.as(UInt16*)[pal_idx]
    end
  end

  def read_io(io_addr : Int) : Byte
    case io_addr
    when 0x000..0x001 then @dispcnt.read_byte(io_addr & 1)
    when 0x002..0x003 then 0_u8 # todo green swap
    when 0x004..0x005 then @dispstat.read_byte(io_addr & 1)
    when 0x006..0x007 then (@vcount >> (8 * (io_addr & 1))).to_u8!
    when 0x008..0x00F then @bgcnt[(io_addr - 0x008) >> 1].read_byte(io_addr & 1)
    when 0x010..0x01F
      bg_num = (io_addr - 0x010) >> 2
      if bit?(io_addr, 1)
        @bgvofs[bg_num].read_byte(io_addr & 1)
      else
        @bghofs[bg_num].read_byte(io_addr & 1)
      end
    when 0x040 then 0xFF_u8 & @win0h.value
    when 0x041 then 0xFF_u8 & @win0h.value >> 8
    when 0x042 then 0xFF_u8 & @win1h.value
    when 0x043 then 0xFF_u8 & @win1h.value >> 8
    when 0x044 then 0xFF_u8 & @win0V.value
    when 0x045 then 0xFF_u8 & @win0V.value >> 8
    when 0x046 then 0xFF_u8 & @win1V.value
    when 0x047 then 0xFF_u8 & @win1V.value >> 8
    when 0x048 then 0xFF_u8 & @winin.value
    when 0x049 then 0xFF_u8 & @winin.value >> 8
    when 0x04A then 0xFF_u8 & @winout.value
    when 0x04B then 0xFF_u8 & @winout.value >> 8
    when 0x04C then 0xFF_u8 & @mosaic.value
    when 0x04D then 0xFF_u8 & @mosaic.value >> 8
    when 0x050 then 0xFF_u8 & @bldcnt.value
    when 0x051 then 0xFF_u8 & @bldcnt.value >> 8
    when 0x052 then 0xFF_u8 & @bldalpha.value
    when 0x053 then 0xFF_u8 & @bldalpha.value >> 8
    when 0x054 then 0xFF_u8 & @bldy.value
    when 0x055 then 0xFF_u8 & @bldy.value >> 8
    else            abort "Unmapped PPU read ~ addr:#{hex_str io_addr.to_u8}"
    end
  end

  def write_io(io_addr : Int, value : Byte) : Nil
    case io_addr
    when 0x000..0x001 then @dispcnt.write_byte(io_addr & 1, value)
    when 0x002..0x003 # undocumented - green swap
    when 0x004..0x005 then @dispstat.write_byte(io_addr & 1, value)
    when 0x006..0x007 # vcount
    when 0x008..0x00F then @bgcnt[(io_addr - 0x008) >> 1].write_byte(io_addr & 1, value)
    when 0x010..0x01F
      bg_num = (io_addr - 0x010) >> 2
      if bit?(io_addr, 1)
        @bgvofs[bg_num].write_byte(io_addr & 1, value)
      else
        @bghofs[bg_num].write_byte(io_addr & 1, value)
      end
    when 0x040 then @win0h.value = (@win0h.value & 0xFF00) | value
    when 0x041 then @win0h.value = (@win0h.value & 0x00FF) | value.to_u16 << 8
    when 0x042 then @win1h.value = (@win1h.value & 0xFF00) | value
    when 0x043 then @win1h.value = (@win1h.value & 0x00FF) | value.to_u16 << 8
    when 0x044 then @win0V.value = (@win0V.value & 0xFF00) | value
    when 0x045 then @win0V.value = (@win0V.value & 0x00FF) | value.to_u16 << 8
    when 0x046 then @win1V.value = (@win1V.value & 0xFF00) | value
    when 0x047 then @win1V.value = (@win1V.value & 0x00FF) | value.to_u16 << 8
    when 0x048 then @winin.value = (@winin.value & 0xFF00) | value
    when 0x049 then @winin.value = (@winin.value & 0x00FF) | value.to_u16 << 8
    when 0x04A then @winout.value = (@winout.value & 0xFF00) | value
    when 0x04B then @winout.value = (@winout.value & 0x00FF) | value.to_u16 << 8
    when 0x04C then @mosaic.value = (@mosaic.value & 0xFF00) | value
    when 0x04D then @mosaic.value = (@mosaic.value & 0x00FF) | value.to_u16 << 8
    when 0x050 then @bldcnt.value = (@bldcnt.value & 0xFF00) | value
    when 0x051 then @bldcnt.value = (@bldcnt.value & 0x00FF) | value.to_u16 << 8
    when 0x052 then @bldalpha.value = (@bldalpha.value & 0xFF00) | value
    when 0x053 then @bldalpha.value = (@bldalpha.value & 0x00FF) | value.to_u16 << 8
    when 0x054 then @bldy.value = (@bldy.value & 0xFF00) | value
    when 0x055 then @bldy.value = (@bldy.value & 0x00FF) | value.to_u16 << 8
    else            puts "Unmapped PPU write ~ addr:#{hex_str io_addr.to_u8}, val:#{value}".colorize(:yellow)
    end
  end
end
