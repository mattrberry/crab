module GBA
  class PPU
    SPRITE_PIXEL = SpritePixel.new 4, 0, false, false # base sprite pixel to fill buffer with on each scanline

    getter framebuffer : Slice(UInt16) = Slice(UInt16).new 0x9600 # framebuffer as 16-bit xBBBBBGGGGGRRRRR
    property frame = false
    @layer_palettes : Slice(Bytes) = Slice.new 4 { Bytes.new 240 }
    @sprite_pixels : Slice(SpritePixel) = Slice(SpritePixel).new 240, SPRITE_PIXEL

    getter pram = Bytes.new 0x400
    getter vram = Bytes.new 0x18000
    getter oam = Bytes.new 0x400

    @dispcnt = Reg::DISPCNT.new 0
    @dispstat = Reg::DISPSTAT.new 0
    @vcount : UInt16 = 0x0000_u16
    @bgcnt = Slice(Reg::BGCNT).new 4 { GBA::Reg::BGCNT.new 0 }
    @bghofs = Slice(Reg::BGOFS).new 4 { GBA::Reg::BGOFS.new 0 }
    @bgvofs = Slice(Reg::BGOFS).new 4 { GBA::Reg::BGOFS.new 0 }
    @bgaff = Slice(Slice(Reg::BGAFF)).new 2 { Slice(GBA::Reg::BGAFF).new 4 { GBA::Reg::BGAFF.new 0 } }
    @bgref = Slice(Slice(Reg::BGREF)).new 2 { Slice(GBA::Reg::BGREF).new 2 { GBA::Reg::BGREF.new 0 } }
    @bgref_int = Slice(Slice(Int32)).new 2 { Slice(Int32).new 2, 0 }
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

    def bitmap? : Bool
      @dispcnt.bg_mode >= 3
    end

    def start_line : Nil
      @gba.scheduler.schedule 960, ->start_hblank, Scheduler::EventType::PPU
    end

    def start_hblank : Nil
      @gba.scheduler.schedule 272, ->end_hblank, Scheduler::EventType::PPU
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
      @gba.scheduler.schedule 0, ->start_line, Scheduler::EventType::PPU
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
    def se_address(tx : Int, ty : Int, screen_size : Int) : Int
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

        se_idx = se_address(tile_x, tile_y, bgcnt.screen_size)
        screen_entry = @vram[screen_base + se_idx * 2 + 1].to_u16 << 8 | @vram[screen_base + se_idx * 2]

        tile_id = bits(screen_entry, 0..9)
        y = (effective_row & 7) ^ (7 * (screen_entry >> 11 & 1))
        x = (effective_col & 7) ^ (7 * (screen_entry >> 10 & 1))

        if bgcnt.color_mode_8bpp
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
      return unless bit?(@dispcnt.value, 12)
      base = 0x10000_u32
      sprites = @oam.unsafe_slice_of(Sprite)
      sprites.each do |sprite|
        next if sprite.obj_shape == 3      # prohibited
        next if sprite.affine_mode == 0b10 # sprite disabled
        x_coord, y_coord = sprite.x_coord.to_i16, sprite.y_coord.to_i16
        x_coord -= 512 if x_coord > 239 # wrap x
        y_coord -= 256 if y_coord > 159 # wrap y
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
          flip_x = bit?(sprite.attr1, 12) && !sprite.affine
          flip_y = bit?(sprite.attr1, 13) && !sprite.affine
          min_x, max_x = Math.max(0, x_coord), Math.min(240, x_coord + width)

          (-(width // 2)...(width // 2)).each do |ix|
            col = center_x + ix
            next unless min_x <= col < max_x

            # transform to texture coordinates
            tex_x = (pa * ix + pb * iy) >> 8
            tex_y = (pc * ix + pd * iy) >> 8

            # bring origin back to top-left of the sprite
            tex_x += (orig_width // 2)
            tex_y += (orig_height // 2)

            next unless 0 <= tex_x < orig_width && 0 <= tex_y < orig_height

            # flip coordinates if necessary
            tex_x = orig_width - tex_x - 1 if flip_x
            tex_y = orig_height - tex_y - 1 if flip_y

            # select pixel offsets within the specified tile
            tile_x = tex_x & 7
            tile_y = tex_y & 7

            tile_id = sprite.tile_idx
            offset = tex_y >> 3
            if @dispcnt.obj_mapping_1d
              offset *= orig_width >> 3
            else
              if sprite.color_mode_8bpp
                offset *= 0x10
              else
                offset *= 0x20
              end
            end
            offset += tex_x >> 3
            if sprite.color_mode_8bpp
              tile_id >>= 1
              tile_id += offset
              pal_idx = @vram[base + tile_id * 0x40 + tile_y * 8 + tile_x]
            else # 4bpp
              tile_id += offset
              palettes = @vram[base + tile_id * 0x20 + tile_y * 4 + (tile_x >> 1)]
              pal_idx = ((palettes >> ((tile_x & 1) * 4)) & 0xF)
              pal_idx += (sprite.palette_bank << 4) if pal_idx > 0 # convert palette address to absolute value
            end

            if sprite.obj_mode == 0b10 # object window
              @sprite_pixels[col] = @sprite_pixels[col].copy_with window: true if pal_idx > 0
            elsif sprite.priority < @sprite_pixels[col].priority || @sprite_pixels[col].palette == 0
              @sprite_pixels[col] = @sprite_pixels[col].copy_with priority: sprite.priority # priority is copied even if the sprite is transparent
              @sprite_pixels[col] = @sprite_pixels[col].copy_with palette: pal_idx.to_u16, blends: sprite.obj_mode == 0b01 if pal_idx > 0
            end
          end
        end
      end
    end

    # Returns a u16 representing the layer enable bits and a bool indicating whether effects are enabled.
    def get_enables(col : Int) : Tuple(UInt16, Bool)
      if @dispcnt.window_0_display && @win0h.x1 <= col < @win0h.x2 && @win0v.y1 <= @vcount < @win0v.y2 # win0
        {@winin.window_0_enable_bits, @winin.window_0_color_special_effect}
      elsif @dispcnt.window_1_display && @win1h.x1 <= col < @win1h.x2 && @win1v.y1 <= @vcount < @win1v.y2 # win1
        {@winin.window_1_enable_bits, @winin.window_1_color_special_effect}
      elsif @dispcnt.obj_window_display && @sprite_pixels[col].window # obj win
        {@winout.obj_window_enable_bits, @winout.obj_window_color_special_effect}
      elsif @dispcnt.window_0_display || @dispcnt.window_1_display || @dispcnt.obj_window_display # winout
        {@winout.outside_enable_bits, @winout.outside_color_special_effect}
      else # no windows
        {@dispcnt.default_enable_bits, true}
      end
    end

    # Simple blending routine just to mix two UInt16 colors.
    def blend(top : UInt16, bot : UInt16, blend_mode : BlendMode) : UInt16
      case blend_mode
      in BlendMode::None then top
      in BlendMode::Blend
        color = (BGR16.new(top) * (Math.min(16, @bldalpha.eva_coefficient) / 16) +
                 BGR16.new(bot) * (Math.min(16, @bldalpha.evb_coefficient) / 16))
        color.value
      in BlendMode::Brighten
        bgr16 = BGR16.new(top)
        (bgr16 + (BGR16.new(0xFFFF) - bgr16) * (Math.min(16, @bldy.evy_coefficient) / 16)).value
      in BlendMode::Darken
        bgr16 = BGR16.new(top)
        (bgr16 - bgr16 * (Math.min(16, @bldy.evy_coefficient) / 16)).value
      end
    end

    # Blend the colors handling special-case sprite logic.
    def blend(top : Color, bot : Color, effects_enabled : Bool) : UInt16
      pram_u16 = @pram.to_unsafe.as(UInt16*)
      top_u16 = pram_u16[top.palette]
      if effects_enabled # only blend if effects are enabled
        bot_u16 = pram_u16[bot.palette]
        top_selected = @bldcnt.layer_target?(top.layer, 1)
        bot_selected = @bldcnt.layer_target?(bot.layer, 2)
        blend_mode = BlendMode.new(@bldcnt.blend_mode)
        if top.special_handling && bot_selected # sprite is semi-transparent and bottom is selected
          return blend(top_u16, bot_u16, BlendMode::Blend)
        elsif top_selected && (bot_selected || blend_mode != BlendMode::Blend) # both selected or bottom isn't needed
          return blend(top_u16, bot_u16, blend_mode)
        end
      end
      top_u16 # fall back to just the top color
    end

    # Select the top two colors at the current position.
    def select_top_colors(enable_bits : Int, col : Int) : Tuple(Color, Color)
      sprite = @sprite_pixels[col]
      backdrop_color = Color.new(0, 5, false)
      top = nil
      4.times do |priority|
        if bit?(enable_bits, 4) && sprite.priority == priority && sprite.palette != 0
          color = Color.new(sprite.palette + 0x100, 4, sprite.blends)
          return {top, color} unless top.nil?
          top = color
        end
        4.times do |bg|
          if bit?(enable_bits, bg) && @bgcnt[bg].priority == priority
            palette = @layer_palettes[bg][col]
            next if palette == 0
            color = Color.new(palette, bg, false)
            return {top, color} unless top.nil?
            top = color
          end
        end
      end
      {top || backdrop_color, backdrop_color}
    end

    # Calculate the color at the current position.
    def calculate_color(col : Int) : UInt16
      enable_bits, effects_enabled = get_enables(col)
      top, bot = select_top_colors(enable_bits, col)
      blend(top, bot, effects_enabled)
    end

    def composite(scanline : Slice(UInt16)) : Nil
      240.times do |col|
        scanline[col] = calculate_color(col)
      end
    end

    def [](io_addr : UInt32) : UInt8
      case io_addr
      when 0x000..0x001 then @dispcnt.read_byte(io_addr & 1)
      when 0x002..0x003 then 0_u8 # todo green swap
      when 0x004..0x005 then @dispstat.read_byte(io_addr & 1)
      when 0x006..0x007 then (@vcount >> (8 * (io_addr & 1))).to_u8!
      when 0x008..0x00F
        bg_num = (io_addr - 0x008) >> 1
        val = @bgcnt[bg_num].read_byte(io_addr & 1)
        val |= 0x20 if (io_addr == 0xD || io_addr == 0xF) && @bgcnt[bg_num].affine_wrap
        val
      when 0x048..0x049 then @winin.read_byte(io_addr & 1)
      when 0x04A..0x04B then @winout.read_byte(io_addr & 1)
      when 0x050..0x051 then @bldcnt.read_byte(io_addr & 1)
      when 0x052..0x053 then @bldalpha.read_byte(io_addr & 1)
      else                   @gba.bus.read_open_bus_value(io_addr)
      end
    end

    def []=(io_addr : UInt32, value : UInt8) : Nil
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
  SIZES = Slice[
    # square
    Slice[{8, 8}, {16, 16}, {32, 32}, {64, 64}],
    # horizontal rectangle
    Slice[{16, 8}, {32, 8}, {32, 16}, {64, 32}],
    # vertical rectangle
    Slice[{8, 16}, {8, 32}, {16, 32}, {32, 64}],
  ]

  record Sprite, attr0 : UInt16, attr1 : UInt16, attr2 : UInt16, aff_param : Int16 do
    # OBJ Attribute 0

    def obj_shape
      bits(attr0, 14..15)
    end

    def color_mode_8bpp
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

    def tile_idx
      bits(attr2, 0..9)
    end

    def priority
      bits(attr2, 10..11)
    end

    def palette_bank
      bits(attr2, 12..15)
    end
  end

  record SpritePixel, priority : UInt16, palette : UInt16, blends : Bool, window : Bool

  # Special_handling indicates a sprite with semi-transparency.
  record Color, palette : Int32, layer : Int32, special_handling : Bool

  enum BlendMode
    None
    Blend
    Brighten
    Darken
  end

  record BGR16, value : UInt16 do # xBBBBBGGGGGRRRRR
    # Create a new BGR16 struct with the given values. Trucates at 5 bits.
    def initialize(blue : Number, green : Number, red : Number)
      @value = (blue <= 0x1F ? blue.to_u16 : 0x1F_u16) << 10 |
               (green <= 0x1F ? green.to_u16 : 0x1F_u16) << 5 |
               (red <= 0x1F ? red.to_u16 : 0x1F_u16)
    end

    def blue : UInt16
      bits(value, 0xA..0xE)
    end

    def green : UInt16
      bits(value, 0x5..0x9)
    end

    def red : UInt16
      bits(value, 0x0..0x4)
    end

    def +(other : BGR16) : BGR16
      BGR16.new(blue + other.blue, green + other.green, red + other.red)
    end

    def -(other : BGR16) : BGR16
      BGR16.new(blue.to_i - other.blue, green.to_i - other.green, red.to_i - other.red)
    end

    def *(operand : Number) : BGR16
      BGR16.new(blue * operand, green * operand, red * operand)
    end
  end
end
