class PPU
  @framebuffer : Slice(UInt16) = Slice(UInt16).new 0x9600 # framebuffer as 16-bit xBBBBBGGGGGRRRRR
  @layer_palettes : Array(Bytes) = Array.new 4 { Bytes.new 240 }
  @sprite_pixels : Slice(SpritePixel) = Slice(SpritePixel).new 240, SpritePixel.new 0, 0, false, false

  getter pram = Bytes.new 0x400
  getter vram = Bytes.new 0x18000
  getter oam = Bytes.new 0x400

  getter dispcnt = Reg::DISPCNT.new 0
  getter dispstat = Reg::DISPSTAT.new 0
  getter vcount : UInt16 = 0x0000_u16
  getter bgcnt = Array(Reg::BGCNT).new 4 { Reg::BGCNT.new 0 }
  getter bghofs = Array(Reg::BGOFS).new 4 { Reg::BGOFS.new 0 }
  getter bgvofs = Array(Reg::BGOFS).new 4 { Reg::BGOFS.new 0 }
  getter bgaff = Array(Array(Reg::BGAFF)).new 2 { Array(Reg::BGAFF).new 4 { Reg::BGAFF.new 0 } }
  getter bgref = Array(Array(Reg::BGREF)).new 2 { Array(Reg::BGREF).new 4 { Reg::BGREF.new 0 } }
  getter win0h = Reg::WINH.new 0
  getter win1h = Reg::WINH.new 0
  getter win0v = Reg::WINV.new 0
  getter win1v = Reg::WINV.new 0
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
    @gba.dma.trigger_hdma if @vcount < 160
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
    @layer_palettes.each &.to_unsafe.clear 240
    @sprite_pixels.to_unsafe.clear(240)
    case @dispcnt.bg_mode
    when 0
      render_reg_bg(0)
      render_reg_bg(1)
      render_reg_bg(2)
      render_reg_bg(3)
      render_sprites
      composite(scanline)
    when 1
      render_reg_bg(0)
      render_reg_bg(1)
      render_aff_bg(2)
      render_sprites
      composite(scanline)
    when 2
      puts "Unsupported background mode: #{@dispcnt.bg_mode}"
    when 3
      240.times { |col| scanline[col] = @vram.to_unsafe.as(UInt16*)[row_base + col] }
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

  def render_reg_bg(bg : Int) : Nil
    return unless bit?(@dispcnt.value, 8 + bg)
    pal_buf = @layer_palettes[bg]

    tw, th = case @bgcnt[bg].screen_size
             when 0b00 then {0x0FF, 0x0FF} # 32x32
             when 0b01 then {0x1FF, 0x0FF} # 64x32
             when 0b10 then {0x0FF, 0x1FF} # 32x64
             when 0b11 then {0x1FF, 0x1FF} # 64x64
             else           raise "Impossible bgcnt screen size: #{@bgcnt[bg].screen_size}"
             end

    screen_base = 0x800_u32 * @bgcnt[bg].screen_base_block
    character_base = @bgcnt[bg].character_base_block.to_u32 * 0x4000
    effective_row = (@vcount.to_u32 + @bgvofs[bg].value) & th
    ty = effective_row >> 3
    240.times do |col|
      effective_col = (col + @bghofs[bg].value) & tw
      tx = effective_col >> 3

      se_idx = se_index(tx, ty, @bgcnt[bg].screen_size)
      screen_entry = @vram[screen_base + se_idx * 2 + 1].to_u16 << 8 | @vram[screen_base + se_idx * 2]

      tile_id = bits(screen_entry, 0..9)
      y = (effective_row & 7) ^ (7 * (screen_entry >> 11 & 1))
      x = (effective_col & 7) ^ (7 * (screen_entry >> 10 & 1))

      if @bgcnt[bg].color_mode # 8bpp
        pal_idx = @vram[character_base + tile_id * 0x40 + y * 8 + x]
      else # 4bpp
        palette_bank = bits(screen_entry, 12..15)
        palettes = @vram[character_base + tile_id * 0x20 + y * 4 + (x >> 1)]
        pal_idx = ((palettes >> ((x & 1) * 4)) & 0xF)
        pal_idx = (palette_bank << 4) + pal_idx if pal_idx > 0
      end
      pal_buf[col] = pal_idx.to_u8
    end
  end

  def render_aff_bg(bg : Int) : Nil
    return unless bit?(@dispcnt.value, 8 + bg)
    pal_buf = @layer_palettes[bg]
    row = @vcount.to_u32

    pa, pb, pc, pd = @bgaff[bg - 2].map { |p| p.value.to_i16!.to_i32! }
    dx, dy = @bgref[bg - 2].map { |p| (p.value << 4).to_i32! >> 4 }

    size = 16 << @bgcnt[bg].screen_size # tiles, always a square
    size_pixels = size << 3

    screen_base = 0x800_u32 * @bgcnt[bg].screen_base_block
    character_base = @bgcnt[bg].character_base_block.to_u32 * 0x4000
    240.times do |col|
      x = ((pa * col + pb * row) + dx) >> 8
      y = ((pc * col + pd * row) + dy) >> 8

      if @bgcnt[bg].affine_wrap
        x %= size_pixels
        y %= size_pixels
      end
      next unless 0 <= x < size_pixels && 0 <= y < size_pixels

      screen_entry = @vram[screen_base + (y >> 3) * size + (x >> 3)].to_u16

      tile_id = bits(screen_entry, 0..9)
      y = (y & 7) ^ (7 * (screen_entry >> 11 & 1))
      x = (x & 7) ^ (7 * (screen_entry >> 10 & 1))

      pal_idx = @vram[character_base + tile_id * 0x40 + y * 8 + x]
      pal_buf[col] = pal_idx.to_u8
    end
  end

  def render_sprites : Nil
    return unless @dispcnt.screen_display_obj
    base = 0x10000_u32
    sprites = Slice(Sprite).new(@oam.to_unsafe.as(Sprite*), 128)
    sprites.each do |sprite|
      next if sprite.obj_shape == 3      # prohibited
      next if sprite.affine_mode == 0b10 # sprite disabled
      x_coord, y_coord = sprite.x_coord.to_i16, sprite.y_coord.to_i16
      x_coord -= 512 if x_coord > 239
      y_coord -= 256 if y_coord > 159
      orig_width, orig_height = SIZES[sprite.obj_shape][sprite.obj_size]
      width, height = orig_width, orig_height
      center_x, center_y = x_coord + width // 2, y_coord + height // 2 # off of center
      if sprite.affine
        oam_affine_entry = sprite.attr1_bits_9_13
        # signed 8.8 fixed-point numbers, need to shr 8
        pa = sprites[oam_affine_entry * 4].aff_param.to_i32
        pb = sprites[oam_affine_entry * 4 + 1].aff_param.to_i32
        pc = sprites[oam_affine_entry * 4 + 2].aff_param.to_i32
        pd = sprites[oam_affine_entry * 4 + 3].aff_param.to_i32
        if sprite.attr0_bit_9 # double-size (rotated sprites won't clip unless scaled)
          center_x += width >> 1
          center_y += height >> 1
          width <<= 1
          height <<= 1
        end
      else # identity matrix if sprite isn't affine (shifted left 8 to match the 8.8 fixed-point)
        pa, pb, pc, pd = 0x100, 0, 0, 0x100
      end
      if y_coord <= @vcount < y_coord + height
        iy = @vcount.to_i16 - center_y
        min_x, max_x = Math.max(0, x_coord), Math.min(240, x_coord + width)
        (-(width // 2)...(width // 2)).each do |ix|
          col = center_x + ix
          next unless min_x <= col < max_x
          # sprite already exists at this pixel && that sprite has higher priority than this one && object window is not enabled
          next if @sprite_pixels[col].palette > 0 && @sprite_pixels[col].priority <= sprite.priority && !@dispcnt.obj_window_display
          # transform to texture coordinates
          px = (pa * ix + pb * iy) >> 8
          py = (pc * ix + pd * iy) >> 8
          # bring origin back to top-left of the sprite
          px += (orig_width // 2)
          py += (orig_height // 2)

          next unless 0 <= px < orig_width && 0 <= py < orig_height

          px = orig_width - px - 1 if bit?(sprite.attr1, 12) && !sprite.affine
          py = orig_height - py - 1 if bit?(sprite.attr1, 13) && !sprite.affine

          x = px & 7
          y = py & 7

          tile_id = sprite.character_name
          offset = py >> 3
          if @dispcnt.obj_character_vram_mapping
            offset *= orig_width >> 3
          else
            if sprite.color_mode
              offset *= 0x10
            else
              offset *= 0x20
            end
          end
          offset += px >> 3
          if sprite.color_mode # 8bpp
            tile_id >>= 1
            tile_id += offset
            pal_idx = @vram[base + tile_id * 0x40 + y * 8 + x]
          else # 4bpp
            tile_id += offset
            palettes = @vram[base + tile_id * 0x20 + y * 4 + (x >> 1)]
            pal_idx = ((palettes >> ((x & 1) * 4)) & 0xF)
            pal_idx += (sprite.palette_number << 4) if pal_idx > 0
          end

          obj_window = @sprite_pixels[col].window || (sprite.obj_mode == 0b10 && pal_idx > 0)
          if @sprite_pixels[col].palette > 0 && @sprite_pixels[col].priority <= sprite.priority # existing sprite is higher priority
            pixel = @sprite_pixels[col]
          else
            pixel = SpritePixel.new(sprite.priority, pal_idx.to_u16, sprite.obj_mode == 0b01, obj_window)
          end
          @sprite_pixels[col] = pixel.copy_with window: obj_window
        end
      end
    end
  end

  def calculate_color(col : Int) : UInt16
    enables, effects = if @dispcnt.window_0_display && @win0h.x1 <= col < @win0h.x2 && @win0v.y1 <= @vcount < @win0v.y2 # win0
                         {bits(@winin.value, 0..4), @winin.window_0_color_special_effect}
                       elsif @dispcnt.window_1_display && @win1h.x1 <= col < @win1h.x2 && @win1v.y1 <= @vcount < @win1v.y2 # win1
                         {bits(@winin.value, 8..12), @winin.window_1_color_special_effect}
                       elsif @dispcnt.obj_window_display && @sprite_pixels[col].window # obj win
                         {bits(@winout.value, 8..12), @winout.obj_window_color_special_effect}
                       elsif @dispcnt.window_0_display || @dispcnt.window_1_display || @dispcnt.obj_window_display # winout
                         {bits(@winout.value, 0..4), @winout.outside_color_special_effect}
                       else # no windows
                         {bits(@dispcnt.value, 8..12), true}
                       end
    top_color = nil
    4.times do |priority|
      if bit?(enables, 4)
        sprite_pixel = @sprite_pixels[col]
        if sprite_pixel.priority == priority
          if sprite_pixel.palette > 0 # todo: abstract out this duplicated work
            selected_color = (@pram + 0x200).to_unsafe.as(UInt16*)[sprite_pixel.palette]
            if !sprite_pixel.window
              if top_color.nil? # todo: brightness for sprites
                top_color = selected_color
                return top_color unless sprite_pixel.blends || (@bldcnt.is_bg_target(4, target: 1) && effects)
              else
                if @bldcnt.is_bg_target(4, target: 2)
                  color = BGR16.new(top_color) * (Math.min(16, @bldalpha.eva_coefficient) / 16) + BGR16.new(selected_color) * (Math.min(16, @bldalpha.evb_coefficient) / 16)
                  return color.value
                else
                  return top_color
                end
              end
            end
          end
        end
      end
      4.times do |bg|
        if bit?(enables, bg)
          if @bgcnt[bg].priority == priority
            palette = @layer_palettes[bg][col]
            next if palette == 0
            selected_color = @pram.to_unsafe.as(UInt16*)[palette]
            if top_color.nil?
              if @bldcnt.color_special_effect == 0 || !@bldcnt.is_bg_target(bg, target: 1) || !effects
                return selected_color
              elsif @bldcnt.color_special_effect == 1 # alpha blending
                top_color = selected_color
              elsif @bldcnt.color_special_effect == 2 # brightness increase
                bgr16 = BGR16.new(selected_color)
                return (bgr16 + (BGR16.new(0xFFFF) - bgr16) * (Math.min(16, @bldy.evy_coefficient) / 16)).value
              else # brightness decrease
                bgr16 = BGR16.new(selected_color)
                return (bgr16 - bgr16 * (Math.min(16, @bldy.evy_coefficient) / 16)).value
              end
            else
              if @bldcnt.is_bg_target(bg, target: 2)
                color = BGR16.new(top_color) * (Math.min(16, @bldalpha.eva_coefficient) / 16) + BGR16.new(selected_color) * (Math.min(16, @bldalpha.evb_coefficient) / 16)
                return color.value
              else # second layer isn't set in bldcnt, don't blend
                return top_color
              end
            end
          end
        end
      end
    end
    top_color || @pram.to_unsafe.as(UInt16*)[0]
  end

  def composite(scanline : Slice(UInt16)) : Nil
    240.times do |col|
      scanline[col] = calculate_color(col)
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
    when 0x020..0x03F
      bg_num = (io_addr & 0x10) >> 4 # (bg 0/1 represents bg 2/3, since those are the only aff bgs)
      offs = io_addr & 0xF
      if offs >= 8
        offs -= 8
        @bgref[bg_num][offs >> 2].read_byte(offs & 3)
      else
        @bgaff[bg_num][offs >> 1].read_byte(offs & 1)
      end
    when 0x040 then 0xFF_u8 & @win0h.value
    when 0x041 then 0xFF_u8 & @win0h.value >> 8
    when 0x042 then 0xFF_u8 & @win1h.value
    when 0x043 then 0xFF_u8 & @win1h.value >> 8
    when 0x044 then 0xFF_u8 & @win0v.value
    when 0x045 then 0xFF_u8 & @win0v.value >> 8
    when 0x046 then 0xFF_u8 & @win1v.value
    when 0x047 then 0xFF_u8 & @win1v.value >> 8
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
    when 0x020..0x03F
      bg_num = (io_addr & 0x10) >> 4 # (bg 0/1 represents bg 2/3, since those are the only aff bgs)
      offs = io_addr & 0xF
      if offs >= 8
        offs -= 8
        @bgref[bg_num][offs >> 2].write_byte(offs & 3, value)
      else
        @bgaff[bg_num][offs >> 1].write_byte(offs & 1, value)
      end
    when 0x040 then @win0h.value = (@win0h.value & 0xFF00) | value
    when 0x041 then @win0h.value = (@win0h.value & 0x00FF) | value.to_u16 << 8
    when 0x042 then @win1h.value = (@win1h.value & 0xFF00) | value
    when 0x043 then @win1h.value = (@win1h.value & 0x00FF) | value.to_u16 << 8
    when 0x044 then @win0v.value = (@win0v.value & 0xFF00) | value
    when 0x045 then @win0v.value = (@win0v.value & 0x00FF) | value.to_u16 << 8
    when 0x046 then @win1v.value = (@win1v.value & 0xFF00) | value
    when 0x047 then @win1v.value = (@win1v.value & 0x00FF) | value.to_u16 << 8
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

# SIZES[SHAPE][SIZE]
SIZES = [
  [ # square
    {8, 8},
    {16, 16},
    {32, 32},
    {64, 64},
  ],
  [ # horizontal rectangle
    {16, 8},
    {32, 8},
    {32, 16},
    {64, 32},
  ],
  [ # vertical rectangle
    {8, 16},
    {8, 32},
    {16, 32},
    {32, 64},
  ],
]

record Sprite, attr0 : UInt16, attr1 : UInt16, attr2 : UInt16, aff_param : Int16 do
  # OBJ Attribute 0

  def obj_shape
    bits(attr0, 14..15)
  end

  def color_mode
    bit?(attr0, 13)
  end

  def obj_mosaic
    bit?(attr0, 12)
  end

  def obj_mode
    bits(attr0, 10..11)
  end

  def attr0_bit_9
    bit?(attr0, 9)
  end

  def affine
    bit?(attr0, 8)
  end

  def affine_mode
    bits(attr0, 8..9)
  end

  def y_coord
    bits(attr0, 0..7)
  end

  # OBJ Attribute 1

  def obj_size
    bits(attr1, 14..15)
  end

  def attr1_bits_9_13
    bits(attr1, 9..13)
  end

  def x_coord
    bits(attr1, 0..8)
  end

  # OBJ Attribute 2

  def character_name
    bits(attr2, 0..9)
  end

  def priority
    bits(attr2, 10..11)
  end

  def palette_number
    bits(attr2, 12..15)
  end
end

record SpritePixel, priority : UInt16, palette : UInt16, blends : Bool, window : Bool
