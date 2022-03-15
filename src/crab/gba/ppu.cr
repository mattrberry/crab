module GBA
  class PPU
    SPRITE_PIXEL = SpritePixel.new 4, 0, false, false # base sprite pixel to fill buffer with on each scanline

    getter framebuffer : Slice(UInt16) = Slice(UInt16).new 0x9600 # framebuffer as 16-bit xBBBBBGGGGGRRRRR
    property frame = false
    @layer_palettes : Array(Bytes) = Array.new 4 { Bytes.new 240 }
    @sprite_pixels : Slice(SpritePixel) = Slice(SpritePixel).new 240, SPRITE_PIXEL

    getter pram = Bytes.new 0x400
    getter vram = Bytes.new 0x18000
    getter oam = Bytes.new 0x400

    @dispcnt = Reg::DISPCNT.new 0
    @dispstat = Reg::DISPSTAT.new 0
    @vcount : UInt16 = 0x0000_u16
    @bgcnt = Array(Reg::BGCNT).new 4 { GBA::Reg::BGCNT.new 0 }
    @bghofs = Array(Reg::BGOFS).new 4 { GBA::Reg::BGOFS.new 0 }
    @bgvofs = Array(Reg::BGOFS).new 4 { GBA::Reg::BGOFS.new 0 }
    @bgaff = Array(Array(Reg::BGAFF)).new 2 { Array(GBA::Reg::BGAFF).new 4 { GBA::Reg::BGAFF.new 0 } }
    @bgref = Array(Array(Reg::BGREF)).new 2 { Array(GBA::Reg::BGREF).new 2 { GBA::Reg::BGREF.new 0 } }
    @bgref_int = Array(Array(Int32)).new 2 { Array(Int32).new 2, 0 }
    @win0h = Reg::WINH.new 0
    @win1h = Reg::WINH.new 0
    @win0v = Reg::WINV.new 0
    @win1v = Reg::WINV.new 0
    @winin = Reg::WININ.new 0
    @winout = Reg::WINOUT.new 0
    @mosaic = Reg::MOSAIC.new 0
    @bldcnt = Reg::BLDCNT.new 0
    @bldalpha = Reg::BLDALPHA.new 0
    @bldy = Reg::BLDY.new 0

    def initialize(@gba : GBA)
      start_line
    end

    def start_line : Nil
      @gba.scheduler.schedule 960, ->start_hblank
    end

    def start_hblank : Nil
      @gba.scheduler.schedule 272, ->end_hblank
      @dispstat.hblank = true
      if @dispstat.hblank_irq_enable
        @gba.interrupts.reg_if.hblank = true
        @gba.interrupts.schedule_interrupt_check
      end
      if @vcount < 160
        scanline
        @bgref_int.each_with_index do |bgrefs, bg_num|
          bgrefs[0] &+= @bgaff[bg_num][1].num # bgx += dmx
          bgrefs[1] &+= @bgaff[bg_num][3].num # bgy += dmy
        end
        @gba.dma.trigger_hdma
      end
    end

    def end_hblank : Nil
      @gba.scheduler.schedule 0, ->start_line
      @dispstat.hblank = false
      @vcount = (@vcount + 1) % 228
      @dispstat.vcounter = @vcount == @dispstat.vcount_setting
      @gba.interrupts.reg_if.vcounter = true if @dispstat.vcounter_irq_enable && @dispstat.vcounter
      if @vcount == 227
        @dispstat.vblank = false
      elsif @vcount == 160
        @dispstat.vblank = true
        @gba.dma.trigger_vdma
        @gba.interrupts.reg_if.vblank = true if @dispstat.vblank_irq_enable
        @bgref.each_with_index { |bgrefs, bg_num| bgrefs.each_with_index { |bgref, ref_num| @bgref_int[bg_num][ref_num] = bgref.num } }
        draw
      end
      @gba.interrupts.schedule_interrupt_check
    end

    def draw : Nil
      @frame = true
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
      @sprite_pixels.map! { SPRITE_PIXEL }
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
        render_aff_bg(2)
        render_aff_bg(3)
        render_sprites
        composite(scanline)
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
      bgcnt = @bgcnt[bg]
      bgvofs = @bgvofs[bg]
      bghofs = @bghofs[bg]

      bg_width, bg_height = case bgcnt.screen_size
                            when 0b00 then {0x0FF, 0x0FF} # 32x32
                            when 0b01 then {0x1FF, 0x0FF} # 64x32
                            when 0b10 then {0x0FF, 0x1FF} # 32x64
                            when 0b11 then {0x1FF, 0x1FF} # 64x64
                            else           raise "Impossible bgcnt screen size: #{bgcnt.screen_size}"
                            end

      screen_base = 0x800_u32 * bgcnt.screen_base_block
      character_base = 0x4000_u32 * bgcnt.character_base_block
      effective_row = (@vcount.to_u32 + bgvofs.offset) & bg_height
      tile_y = effective_row >> 3
      240.times do |col|
        effective_col = (col + bghofs.offset) & bg_width
        tile_x = effective_col >> 3

        se_idx = se_index(tile_x, tile_y, bgcnt.screen_size)
        screen_entry = @vram[screen_base + se_idx * 2 + 1].to_u16 << 8 | @vram[screen_base + se_idx * 2]

        tile_id = bits(screen_entry, 0..9)
        y = (effective_row & 7) ^ (7 * (screen_entry >> 11 & 1))
        x = (effective_col & 7) ^ (7 * (screen_entry >> 10 & 1))

        if bgcnt.color_mode # 8bpp
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
      bgcnt = @bgcnt[bg]

      dx, _, dy, _ = @bgaff[bg - 2].map &.num
      int_x, int_y = @bgref_int[bg - 2]

      size = 16 << bgcnt.screen_size # tiles, always a square
      size_pixels = size << 3

      screen_base = 0x800_u32 * bgcnt.screen_base_block
      character_base = 0x4000_u32 * bgcnt.character_base_block
      240.times do |col|
        x = int_x >> 8
        y = int_y >> 8
        int_x += dx
        int_y += dy

        if bgcnt.affine_wrap
          x %= size_pixels
          y %= size_pixels
        end
        next unless 0 <= x < size_pixels && 0 <= y < size_pixels

        # affine screen entries are merely one-byte tile indices
        tile_id = @vram[screen_base + (y >> 3) * size + (x >> 3)]
        pal_idx = @vram[character_base + 0x40 * tile_id + 8 * (y & 7) + (x & 7)]
        pal_buf[col] = pal_idx
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

            if sprite.obj_mode == 0b10
              @sprite_pixels[col] = @sprite_pixels[col].copy_with window: true if pal_idx > 0
            elsif sprite.priority < @sprite_pixels[col].priority || @sprite_pixels[col].palette == 0
              @sprite_pixels[col] = @sprite_pixels[col].copy_with priority: sprite.priority
              @sprite_pixels[col] = @sprite_pixels[col].copy_with palette: pal_idx.to_u16, blends: sprite.obj_mode == 0b01 if pal_idx > 0
            end
          end
        end
      end
    end

    def get_enables(col : Int) : Tuple(UInt16, Bool)
      if @dispcnt.window_0_display && @win0h.x1 <= col < @win0h.x2 && @win0v.y1 <= @vcount < @win0v.y2 # win0
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
    end

    def calculate_color(col : Int) : UInt16
      enables, effects = get_enables(col)
      top_color = nil
      4.times do |priority|
        if bit?(enables, 4)
          sprite_pixel = @sprite_pixels[col]
          if sprite_pixel.priority == priority && sprite_pixel.palette > 0
            selected_color = (@pram + 0x200).to_unsafe.as(UInt16*)[sprite_pixel.palette]
            if top_color.nil? # todo: brightness for sprites
              if !(sprite_pixel.blends || (@bldcnt.is_bg_target(4, target: 1) && effects))
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
              if @bldcnt.is_bg_target(4, target: 2) || sprite_pixel.blends
                color = BGR16.new(top_color) * (Math.min(16, @bldalpha.eva_coefficient) / 16) + BGR16.new(selected_color) * (Math.min(16, @bldalpha.evb_coefficient) / 16)
                return color.value
              else
                return top_color
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
      when 0x040..0x041 then @win0h.read_byte(io_addr & 1)
      when 0x042..0x043 then @win1h.read_byte(io_addr & 1)
      when 0x044..0x045 then @win0v.read_byte(io_addr & 1)
      when 0x046..0x047 then @win1v.read_byte(io_addr & 1)
      when 0x048..0x049 then @winin.read_byte(io_addr & 1)
      when 0x04A..0x04B then @winout.read_byte(io_addr & 1)
      when 0x04C..0x04D then @mosaic.read_byte(io_addr & 1)
      when 0x050..0x051 then @bldcnt.read_byte(io_addr & 1)
      when 0x052..0x053 then @bldalpha.read_byte(io_addr & 1)
      when 0x054..0x055 then @bldy.read_byte(io_addr & 1)
      else                   log "Unmapped PPU read ~ addr:#{hex_str io_addr.to_u8}"; 0_u8 # todo: open bus
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
          @bgref_int[bg_num][offs >> 2] = @bgref[bg_num][offs >> 2].num
        else
          @bgaff[bg_num][offs >> 1].write_byte(offs & 1, value)
        end
      when 0x040..0x041 then @win0h.write_byte(io_addr & 1, value)
      when 0x042..0x043 then @win1h.write_byte(io_addr & 1, value)
      when 0x044..0x045 then @win0v.write_byte(io_addr & 1, value)
      when 0x046..0x047 then @win1v.write_byte(io_addr & 1, value)
      when 0x048..0x049 then @winin.write_byte(io_addr & 1, value)
      when 0x04A..0x04B then @winout.write_byte(io_addr & 1, value)
      when 0x04C..0x04D then @mosaic.write_byte(io_addr & 1, value)
      when 0x050..0x051 then @bldcnt.write_byte(io_addr & 1, value)
      when 0x052..0x053 then @bldalpha.write_byte(io_addr & 1, value)
      when 0x054..0x055 then @bldy.write_byte(io_addr & 1, value)
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
end
