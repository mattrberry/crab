module GB
  struct Pixel
    property color : UInt8     # 0-3
    property palette : UInt8   # 0-7
    property oam_idx : UInt8   # OAM index for sprite
    property obj_to_bg : UInt8 # OBJ-to_BG Priority bit

    def initialize(@color : UInt8, @palette : UInt8, @oam_idx : UInt8, @obj_to_bg : UInt8)
    end
  end

  class FifoPPU < PPU
    @fifo = Deque(Pixel).new 8
    @fifo_sprite = Deque(Pixel).new 8

    @fetch_counter = 0
    @fetch_counter_sprite = 0
    @fetcher_x = 0
    @lx : Int32 = 0
    @smooth_scroll_sampled = false
    @dropped_first_fetch = false
    @fetching_window = false
    @fetching_sprite = false

    @tile_num : UInt8 = 0x00
    @tile_attrs : UInt8 = 0x00
    @tile_data_low : UInt8 = 0x00
    @tile_data_high : UInt8 = 0x00

    @sprites = Array(Sprite).new

    @current_window_line = -1

    enum FetchStage
      GET_TILE
      GET_TILE_DATA_LOW
      GET_TILE_DATA_HIGH
      PUSH_PIXEL
      SLEEP
    end

    FETCHER_ORDER = [
      FetchStage::SLEEP, FetchStage::GET_TILE,
      FetchStage::SLEEP, FetchStage::GET_TILE_DATA_LOW,
      FetchStage::SLEEP, FetchStage::GET_TILE_DATA_HIGH,
      FetchStage::PUSH_PIXEL,
    ]

    def sample_smooth_scrolling
      @smooth_scroll_sampled = true
      if @fetching_window
        @lx = -Math.max(0, 7 - @wx)
      else
        @lx = -(7 & @scx)
      end
    end

    def reset_bg_fifo(fetching_window : Bool) : Nil
      @fifo.clear
      @fetcher_x = 0
      @fetch_counter = 0
      @fetching_window = fetching_window
      @current_window_line += 1 if @fetching_window
    end

    def reset_sprite_fifo : Nil
      @fifo_sprite.clear
      @fetch_counter_sprite = 0
      @fetching_sprite = false
    end

    # get first 10 sprites on scanline, ordered
    def get_sprites : Array(Sprite)
      sprites = [] of Sprite
      (0x00_u8..0x9F_u8).step 4 do |sprite_address|
        sprite = Sprite.new @sprite_table, sprite_address
        if sprite.on_line @ly, sprite_height
          index = 0
          sprites.each do |sprite_elm|
            break if sprite.x < sprite_elm.x
            index += 1
          end
          sprites.insert index, sprite
        end
        break if sprites.size >= 10
      end
      sprites
    end

    def tick_bg_fetcher : Nil
      case FETCHER_ORDER[@fetch_counter]
      in FetchStage::GET_TILE
        if @fetching_window
          map = window_tile_map == 0 ? 0x1800 : 0x1C00 # 0x9800 : 0x9C00
          offset = @fetcher_x + ((@current_window_line >> 3) * 32)
        else
          map = bg_tile_map == 0 ? 0x1800 : 0x1C00 # 0x9800 : 0x9C00
          offset = ((@fetcher_x + (@scx >> 3)) & 0x1F) + ((((@ly.to_u16 + @scy) >> 3) * 32) & 0x3FF)
        end
        @tile_num = @vram[0][map + offset]
        @tile_attrs = @vram[1][map + offset] # vram[1] is all 0x00 if running in dmg mode
        @fetch_counter += 1
      in FetchStage::GET_TILE_DATA_LOW, FetchStage::GET_TILE_DATA_HIGH
        if bg_window_tile_data > 0
          tile_num = @tile_num
          tile_data_table = 0x0000 # 0x8000
        else
          tile_num = @tile_num.to_i8!
          tile_data_table = 0x1000 # 0x9000
        end
        tile_ptr = tile_data_table + 16 * tile_num
        bank_num = (@tile_attrs & 0b00001000) >> 3
        tile_row = @fetching_window ? @current_window_line & 7 : (@ly.to_u16 + @scy) & 7
        tile_row = 7 - tile_row if @tile_attrs & 0b01000000 > 0
        if FETCHER_ORDER[@fetch_counter] == FetchStage::GET_TILE_DATA_LOW
          @tile_data_low = @vram[bank_num][tile_ptr + tile_row * 2]
          @fetch_counter += 1
        else
          @tile_data_high = @vram[bank_num][tile_ptr + tile_row * 2 + 1]
          @fetch_counter += 1
          unless @dropped_first_fetch
            @dropped_first_fetch = true
            @fetch_counter = 0 # drop first tile
          end
        end
      in FetchStage::PUSH_PIXEL
        if @fifo.size == 0
          bg_enabled = bg_display? || @cgb_ptr.value
          @fetcher_x += 1
          8.times do |col|
            shift = @tile_attrs & 0b00100000 > 0 ? col : 7 - col
            lsb = (@tile_data_low >> shift) & 0x1
            msb = (@tile_data_high >> shift) & 0x1
            color = (msb << 1) | lsb
            @fifo.push Pixel.new(bg_enabled ? color : 0_u8, @tile_attrs & 0x7, 0, (@tile_attrs & 0x80) >> 7)
          end
          @fetch_counter += 1
        end
      in FetchStage::SLEEP
        @fetch_counter += 1
      end
      @fetch_counter %= FETCHER_ORDER.size
    end

    def tick_sprite_fetcher : Nil
      case FETCHER_ORDER[@fetch_counter_sprite]
      in FetchStage::GET_TILE
        @fetch_counter_sprite += 1
      in FetchStage::GET_TILE_DATA_LOW
        @fetch_counter_sprite += 1
      in FetchStage::GET_TILE_DATA_HIGH
        sprite = @sprites.shift
        bytes = sprite.bytes @ly, sprite_height
        8.times do |col|
          shift = sprite.x_flip? ? col : 7 - col
          lsb = (@vram[@cgb_ptr.value ? sprite.bank_num : 0][bytes[0]] >> shift) & 0x1
          msb = (@vram[@cgb_ptr.value ? sprite.bank_num : 0][bytes[1]] >> shift) & 0x1
          color = (msb << 1) | lsb
          pixel = Pixel.new(color, @cgb_ptr.value ? sprite.cgb_palette_number : sprite.dmg_palette_number, sprite.oam_idx, sprite.priority)
          if col + sprite.x - 8 >= @lx
            if col >= @fifo_sprite.size
              @fifo_sprite.push pixel
            elsif @fifo_sprite[col].color == 0 || (@cgb_ptr.value && pixel.oam_idx <= @fifo_sprite[col].oam_idx && pixel.color != 0)
              @fifo_sprite[col] = pixel
            end
          end
        end
        @fetching_sprite = !@sprites.empty? && @sprites[0].x == sprite.x
        @fetch_counter_sprite += 1
      in FetchStage::PUSH_PIXEL
        @fetch_counter_sprite += 1
      in FetchStage::SLEEP
        @fetch_counter_sprite += 1
      end
      @fetch_counter_sprite %= FETCHER_ORDER.size
    end

    def sprite_wins?(bg_pixel : Pixel, sprite_pixel : Pixel) : Bool
      if sprite_enabled? && sprite_pixel.color > 0
        if @cgb_ptr.value
          !bg_display? || bg_pixel.color == 0 || (bg_pixel.obj_to_bg == 0 && sprite_pixel.obj_to_bg == 0)
        else
          sprite_pixel.obj_to_bg == 0 || bg_pixel.color == 0
        end
      else
        false
      end
    end

    def tick_shifter : Nil
      if @fifo.size > 0
        bg_pixel = @fifo.shift
        sprite_pixel = @fifo_sprite.shift if @fifo_sprite.size > 0
        sample_smooth_scrolling unless @smooth_scroll_sampled
        if @lx >= 0 # otherwise drop pixel on floor
          if !sprite_pixel.nil? && sprite_wins? bg_pixel, sprite_pixel
            pixel = sprite_pixel
            palette = sprite_pixel.palette == 0 ? @obp0 : @obp1
            arr = @obj_pram
          else
            pixel = bg_pixel
            palette = @bgp
            arr = @pram
          end
          color = @cgb_ptr.value ? pixel.color : palette[pixel.color]
          @framebuffer[WIDTH * @ly + @lx] = arr.to_unsafe.as(UInt16*)[4 * pixel.palette + color]
        end
        @lx += 1
        if @lx == WIDTH
          self.mode_flag = 0
        end
        if window_enabled? && @ly >= @wy && @lx + 7 >= @wx && !@fetching_window && @window_trigger
          reset_bg_fifo fetching_window: true
        end
        if sprite_enabled? && @sprites.size > 0 && @lx + 8 >= @sprites[0].x
          @fetching_sprite = true
          @fetch_counter_sprite = 0
        end
      end
    end

    # tick ppu forward by specified number of cycles
    def tick(cycles : Int) : Nil
      if lcd_enabled?
        cycles.times do
          case self.mode_flag
          when 2 # OAM search
            if @cycle_counter == 79
              self.mode_flag = 3
              @window_trigger = true if @ly == @wy
              reset_bg_fifo fetching_window: window_enabled? && @ly >= @wy && @wx <= 7 && @window_trigger
              reset_sprite_fifo
              @lx = 0
              @smooth_scroll_sampled = false
              @dropped_first_fetch = false
              @sprites = get_sprites
            end
          when 3 # drawing
            tick_bg_fetcher unless @fetching_sprite
            tick_sprite_fetcher if @fetching_sprite
            tick_shifter unless @fetching_sprite
          when 0 # hblank
            if @cycle_counter == 456
              @cycle_counter = 0
              @ly += 1
              if @ly == HEIGHT     # final row of screen complete
                self.mode_flag = 1 # switch to vblank
                @gb.interrupts.vblank_interrupt = true
                @frame = true
                @current_window_line = -1
              else
                self.mode_flag = 2 # switch to oam search
              end
            end
          when 1 # vblank
            if @cycle_counter == 456
              @cycle_counter = 0
              @ly += 1 if @ly != 0
              handle_stat_interrupt
              if @ly == 0          # end of vblank reached (ly has already shortcut to 0)
                self.mode_flag = 2 # switch to oam search
                # todo: I think the timing here might be _just wrong_
              end
            end
            @ly = 0 if @ly == 153 && @cycle_counter > 4 # shortcut ly to from 153 to 0 after 4 cycles
          end
          @cycle_counter += 1
        end
      else                 # lcd is disabled
        @cycle_counter = 0 # reset cycle counter
        self.mode_flag = 0 # reset to mode 0
        @ly = 0            # reset ly
      end
    end
  end
end
