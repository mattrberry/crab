module GB
  class ScanlinePPU < PPU
    # get first 10 sprites on scanline, ordered
    # the order dictates how sprites should render, with the first ones on the bottom
    def get_sprites : Array(Sprite)
      sprites = [] of Sprite
      (0x00..0x9F).step 4 do |sprite_address|
        sprite = Sprite.new @sprite_table[sprite_address], @sprite_table[sprite_address + 1], @sprite_table[sprite_address + 2], @sprite_table[sprite_address + 3]
        if sprite.on_line @ly, sprite_height
          index = 0
          if !@cgb_ptr.value
            sprites.each do |sprite_elm|
              break if sprite.x >= sprite_elm.x
              index += 1
            end
          end
          sprites.insert index, sprite
        end
        break if sprites.size >= 10
      end
      sprites
    end

    # color idx, BG-to-OAM priority bit
    @scanline_color_vals = Array(Tuple(UInt8, Bool)).new WIDTH, {0_u8, false}

    def scanline
      @current_window_line = 0 if @ly == 0
      should_increment_window_line = false
      window_map = window_tile_map == 0_u8 ? 0x1800 : 0x1C00       # 0x9800 : 0x9C00
      background_map = bg_tile_map == 0_u8 ? 0x1800 : 0x1C00       # 0x9800 : 0x9C00
      tile_data_table = bg_window_tile_data == 0 ? 0x1000 : 0x0000 # 0x9000 : 0x8000
      tile_row_window = @current_window_line & 7
      tile_row = (@ly.to_u16 + @scy) & 7
      WIDTH.times do |x|
        if window_enabled? && @ly >= @wy && x + 7 >= @wx && @window_trigger
          should_increment_window_line = true
          tile_num_addr = window_map + ((x + 7 - @wx) >> 3) + ((@current_window_line >> 3) * 32)
          tile_num = @vram[0][tile_num_addr]
          tile_num = tile_num.to_i8! if bg_window_tile_data == 0
          tile_ptr = tile_data_table + 16 * tile_num
          bank_num = @cgb_ptr.value ? (@vram[1][tile_num_addr] & 0b00001000) >> 3 : 0
          if @cgb_ptr.value && @vram[1][tile_num_addr] & 0b01000000 > 0
            byte_1 = @vram[bank_num][tile_ptr + (7 - tile_row_window) * 2]
            byte_2 = @vram[bank_num][tile_ptr + (7 - tile_row_window) * 2 + 1]
          else
            byte_1 = @vram[bank_num][tile_ptr + tile_row_window * 2]
            byte_2 = @vram[bank_num][tile_ptr + tile_row_window * 2 + 1]
          end
          if @cgb_ptr.value && @vram[1][tile_num_addr] & 0b00100000 > 0
            lsb = (byte_1 >> ((x + 7 - @wx) & 7)) & 0x1
            msb = (byte_2 >> ((x + 7 - @wx) & 7)) & 0x1
          else
            lsb = (byte_1 >> (7 - ((x + 7 - @wx) & 7))) & 0x1
            msb = (byte_2 >> (7 - ((x + 7 - @wx) & 7))) & 0x1
          end
          color = (msb << 1) | lsb
          @scanline_color_vals[x] = {color, @vram[1][tile_num_addr] & 0x80 > 0}
          if @cgb_ptr.value
            @framebuffer[WIDTH * @ly + x] = @pram.to_unsafe.as(UInt16*)[4 * (@vram[1][tile_num_addr] & 0b111) + color]
          else
            @framebuffer[WIDTH * @ly + x] = @pram.to_unsafe.as(UInt16*)[@bgp[color]]
          end
        elsif bg_display? || @cgb_ptr.value
          tile_num_addr = background_map + (((x + @scx) >> 3) & 0x1F) + ((((@ly.to_u16 + @scy) >> 3) * 32) & 0x3FF)
          tile_num = @vram[0][tile_num_addr]
          tile_num = tile_num.to_i8! if bg_window_tile_data == 0
          tile_ptr = tile_data_table + 16 * tile_num
          bank_num = @cgb_ptr.value ? (@vram[1][tile_num_addr] & 0b00001000) >> 3 : 0
          if @cgb_ptr.value && @vram[1][tile_num_addr] & 0b01000000 > 0
            byte_1 = @vram[bank_num][tile_ptr + (7 - tile_row) * 2]
            byte_2 = @vram[bank_num][tile_ptr + (7 - tile_row) * 2 + 1]
          else
            byte_1 = @vram[bank_num][tile_ptr + tile_row * 2]
            byte_2 = @vram[bank_num][tile_ptr + tile_row * 2 + 1]
          end
          if @cgb_ptr.value && @vram[1][tile_num_addr] & 0b00100000 > 0
            lsb = (byte_1 >> ((x + @scx) & 7)) & 0x1
            msb = (byte_2 >> ((x + @scx) & 7)) & 0x1
          else
            lsb = (byte_1 >> (7 - ((x + @scx) & 7))) & 0x1
            msb = (byte_2 >> (7 - ((x + @scx) & 7))) & 0x1
          end
          color = (msb << 1) | lsb
          @scanline_color_vals[x] = {color, @vram[1][tile_num_addr] & 0x80 > 0}
          if @cgb_ptr.value
            @framebuffer[WIDTH * @ly + x] = @pram.to_unsafe.as(UInt16*)[4 * (@vram[1][tile_num_addr] & 0b111) + color]
          else
            @framebuffer[WIDTH * @ly + x] = @pram.to_unsafe.as(UInt16*)[@bgp[color]]
          end
        end
      end
      @current_window_line += 1 if should_increment_window_line

      if sprite_enabled?
        get_sprites.each do |sprite|
          bytes = sprite.bytes @ly, sprite_height
          8.times do |col|
            x = col + sprite.x - 8
            next unless 0 <= x < WIDTH # only render sprites on screen
            if sprite.x_flip?
              lsb = (@vram[@cgb_ptr.value ? sprite.bank_num : 0][bytes[0]] >> col) & 0x1
              msb = (@vram[@cgb_ptr.value ? sprite.bank_num : 0][bytes[1]] >> col) & 0x1
            else
              lsb = (@vram[@cgb_ptr.value ? sprite.bank_num : 0][bytes[0]] >> (7 - col)) & 0x1
              msb = (@vram[@cgb_ptr.value ? sprite.bank_num : 0][bytes[1]] >> (7 - col)) & 0x1
            end
            color = (msb << 1) | lsb
            if color > 0 # color 0 is transparent
              if @cgb_ptr.value
                # if !bg_display, then objects are always on top in cgb mode
                # objects are always on top of bg/window color 0
                # objects are on top of bg/window colors 1-3 if bg_priority and object priority are both unset
                if !bg_display? || @scanline_color_vals[x][0] == 0 || (!@scanline_color_vals[x][1] && sprite.priority == 0)
                  @framebuffer[WIDTH * @ly + x] = @obj_pram.to_unsafe.as(UInt16*)[4 * sprite.cgb_palette_number + color]
                end
              else
                if sprite.priority == 0 || @scanline_color_vals[x][0] == 0
                  palette = sprite.dmg_palette_number == 0 ? @obp0 : @obp1
                  @framebuffer[WIDTH * @ly + x] = @obj_pram.to_unsafe.as(UInt16*)[palette[color]]
                end
              end
            end
          end
        end
      end
    end

    # tick ppu forward by specified number of cycles
    def tick(cycles : Int) : Nil
      @cycle_counter += cycles
      if lcd_enabled?
        if self.mode_flag == 2    # oam search
          if @cycle_counter >= 80 # end of oam search reached
            @cycle_counter -= 80  # reset cycle_counter, saving extra cycles
            self.mode_flag = 3    # switch to drawing
            @window_trigger = true if @ly == @wy
          end
        elsif self.mode_flag == 3  # drawing
          if @cycle_counter >= 172 # end of drawing reached
            @cycle_counter -= 172  # reset cycle_counter, saving extra cycles
            self.mode_flag = 0     # switch to hblank
            scanline               # store scanline data
          end
        elsif self.mode_flag == 0  # hblank
          if @cycle_counter >= 204 # end of hblank reached
            @cycle_counter -= 204  # reset cycle_counter, saving extra cycles
            @ly += 1
            if @ly == HEIGHT     # final row of screen complete
              self.mode_flag = 1 # switch to vblank
              @gb.interrupts.vblank_interrupt = true
              @frame = true
            else
              self.mode_flag = 2 # switch to oam search
            end
          end
        elsif self.mode_flag == 1  # vblank
          if @cycle_counter >= 456 # end of line reached
            @cycle_counter -= 456  # reset cycle_counter, saving extra cycles
            @ly += 1 if @ly != 0
            handle_stat_interrupt
            if @ly == 0          # end of vblank reached (ly has already shortcut to 0)
              self.mode_flag = 2 # switch to oam search
            end
          end
          @ly = 0 if @ly == 153 && @cycle_counter > 4 # shortcut ly to from 153 to 0 after 4 cycles
        else
          raise "Invalid mode #{self.mode_flag}"
        end
      else                 # lcd is disabled
        @cycle_counter = 0 # reset cycle cycle_counter
        self.mode_flag = 0 # reset to mode 0
        @ly = 0            # reset ly
      end
    end
  end
end
