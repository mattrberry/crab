module GB
  class Memory
    ROM_BANK_0    = 0x0000..0x3FFF
    ROM_BANK_N    = 0x4000..0x7FFF
    VRAM          = 0x8000..0x9FFF
    EXTERNAL_RAM  = 0xA000..0xBFFF
    WORK_RAM_0    = 0xC000..0xCFFF
    WORK_RAM_N    = 0xD000..0xDFFF
    ECHO          = 0xE000..0xFDFF
    OAM           = 0xFE00..0xFE9F
    NOT_USABLE    = 0xFEA0..0xFEFF
    IO_PORTS      = 0xFF00..0xFF7F
    HRAM          = 0xFF80..0xFFFE
    INTERRUPT_REG = 0xFFFF

    @cartridge : Cartridge
    @interrupts : Interrupts
    @ppu : PPU
    @apu : APU
    @timer : Timer
    @joypad : Joypad
    @scheduler : Scheduler
    @cgb_ptr : Pointer(Bool)

    @wram = Slice(Bytes).new 8 { Bytes.new GB::Memory::WORK_RAM_N.size }
    @wram_bank : UInt8 = 1
    @hram = Bytes.new HRAM.size
    @ff72 : UInt8 = 0x00
    @ff73 : UInt8 = 0x00
    @ff74 : UInt8 = 0x00
    @ff75 : UInt8 = 0x00
    @ff76 : UInt8 = 0x00
    @ff77 : UInt8 = 0x00
    property bootrom = Bytes.new 0
    @cycle_tick_count = 0

    # From I conversation I had with gekkio on the EmuDev Discord: (todo)

    # the DMA controller takes over the source bus, which is either the external bus or the video ram bus
    # and obviously the OAM itself since it's the target
    # nothing else is affected by DMA
    # in other words:
    # * if the external bus is the source bus, accessing these lead to conflict situations: work RAM, anything on the cartridge. Everything else (including video RAM) doesn't lead to conflicts
    # * if the video RAM is the source bus, accessing it leads to a conflict situation. Everything else (including work RAM, and the cartridge) doesn't lead to conflicts
    #
    # if the DMA source bus is read, you always get the current byte read by the DMA controller
    # accessing the target bus (= OAM) works differently, and returning 0xff is probably reasonable until more information is gathered...I haven't yet studied OAM very much so I don't yet know the right answers

    # As of right now, my DMA implementation gets the timing correct and block
    # access to OAM during DMA. It does not properly emulate collisions in the
    # DMA source, as described above.
    @dma : UInt8 = 0x00
    @current_dma_source : UInt16 = 0x0000
    @internal_dma_timer = 0
    @dma_position : UInt8 = 0xA0
    @requested_oam_dma_transfer : Bool = false
    @next_dma_counter : UInt8 = 0x00

    @requested_speed_switch : Bool = false
    @current_speed : UInt8 = 0 # 0 (single) or 1 (double)

    def stop_instr : Nil
      if @requested_speed_switch && @cgb_ptr.value
        @requested_speed_switch = false
        @current_speed ^= 1 # toggle between 0 and 1
        @scheduler.speed_mode = @current_speed
      end
    end

    # keep other components in sync with memory, usually before memory access
    def tick_components(cycles = 4, from_cpu = true, ignore_speed = false) : Nil
      @cycle_tick_count += cycles if from_cpu
      @scheduler.tick cycles
      @ppu.tick ignore_speed ? cycles : cycles >> @current_speed
      @timer.tick cycles
      dma_tick cycles
    end

    def reset_cycle_count : Nil
      @cycle_tick_count = 0
    end

    # tick remainder of expected cycles, then reset counter
    def tick_extra(total_expected_cycles : Int) : Nil
      raise "Operation took #{@cycle_tick_count} cycles, but only expected #{total_expected_cycles}" if @cycle_tick_count > total_expected_cycles
      remaining = total_expected_cycles - @cycle_tick_count
      tick_components remaining if remaining > 0
      reset_cycle_count
    end

    def initialize(@gb : GB)
      @cartridge = gb.cartridge
      @interrupts = gb.interrupts
      @ppu = gb.ppu
      @apu = gb.apu
      @timer = gb.timer
      @joypad = gb.joypad
      @scheduler = gb.scheduler
      @cgb_ptr = gb.cgb_ptr
      bootrom = gb.bootrom
      unless bootrom.nil?
        File.open bootrom do |file|
          @bootrom = Bytes.new file.size
          file.read @bootrom
        end
      end
    end

    def skip_boot : Nil
      @bootrom = Bytes.new 0
      write_byte 0xFF10, 0x80_u8 # NR10
      write_byte 0xFF11, 0xBF_u8 # NR11
      write_byte 0xFF12, 0xF3_u8 # NR12
      write_byte 0xFF14, 0xBF_u8 # NR14
      write_byte 0xFF16, 0x3F_u8 # NR21
      write_byte 0xFF17, 0x00_u8 # NR22
      write_byte 0xFF19, 0xBF_u8 # NR24
      write_byte 0xFF1A, 0x7F_u8 # NR30
      write_byte 0xFF1B, 0xFF_u8 # NR31
      write_byte 0xFF1C, 0x9F_u8 # NR32
      write_byte 0xFF1E, 0xBF_u8 # NR33
      write_byte 0xFF20, 0xFF_u8 # NR41
      write_byte 0xFF21, 0x00_u8 # NR42
      write_byte 0xFF22, 0x00_u8 # NR43
      write_byte 0xFF23, 0xBF_u8 # NR44
      write_byte 0xFF24, 0x77_u8 # NR50
      write_byte 0xFF25, 0xF3_u8 # NR51
      write_byte 0xFF26, 0xF1_u8 # NR52
      write_byte 0xFF40, 0x91_u8 # LCDC
      write_byte 0xFF42, 0x00_u8 # SCY
      write_byte 0xFF43, 0x00_u8 # SCX
      write_byte 0xFF45, 0x00_u8 # LYC
      write_byte 0xFF47, 0xFC_u8 # BGP
      write_byte 0xFF48, 0xFF_u8 # OBP0
      write_byte 0xFF49, 0xFF_u8 # OBP1
      write_byte 0xFF4A, 0x00_u8 # WY
      write_byte 0xFF4B, 0x00_u8 # WX
      write_byte 0xFFFF, 0x00_u8 # IE
    end

    # read 8 bits from memory (doesn't tick components)
    def read_byte(index : Int) : UInt8
      return @bootrom[index] if @bootrom.size > 0 && (0x000 <= index < 0x100 || 0x200 <= index < 0x900)
      case index
      when ROM_BANK_0   then @cartridge[index]
      when ROM_BANK_N   then @cartridge[index]
      when VRAM         then @ppu[index]
      when EXTERNAL_RAM then @cartridge[index]
      when WORK_RAM_0   then @wram[0][index - WORK_RAM_0.begin]
      when WORK_RAM_N   then @wram[@wram_bank][index - WORK_RAM_N.begin]
      when ECHO         then read_byte index - 0x2000
      when OAM          then @ppu[index]
      when NOT_USABLE   then 0_u8
      when IO_PORTS
        case index
        when 0xFF00         then @joypad.read
        when 0xFF04..0xFF07 then @timer[index]
        when 0xFF0F         then @interrupts[index]
        when 0xFF10..0xFF3F then @apu[index]
        when 0xFF46         then @dma
        when 0xFF40..0xFF4B then @ppu[index]
        when 0xFF4D
          if @cgb_ptr.value
            0x7E_u8 | @current_speed << 7 | (@requested_speed_switch ? 1 : 0)
          else
            0xFF_u8
          end
        when 0xFF4F         then @ppu[index]
        when 0xFF51..0xFF55 then @ppu[index]
        when 0xFF68..0xFF6B then @ppu[index]
        when 0xFF70         then @cgb_ptr.value ? 0xF8_u8 | @wram_bank : 0xFF_u8
        when 0xFF72         then @ff72                            # (todo) undocumented register
        when 0xFF73         then @ff73                            # (todo) undocumented register
        when 0xFF74         then @cgb_ptr.value ? @ff74 : 0xFF_u8 # (todo) undocumented register
        when 0xFF75         then @ff75                            # (todo) undocumented register
        when 0xFF76         then 0x00_u8                          # (todo) lower bits should have apu channel 1/2 PCM amp
        when 0xFF77         then 0x00_u8                          # (todo) lower bits should have apu channel 3/4 PCM amp
        else                     0xFF_u8
        end
      when HRAM          then @hram[index - HRAM.begin]
      when INTERRUPT_REG then @interrupts[index]
      else                    raise "FAILED TO GET INDEX #{index}"
      end
    end

    # read 8 bits from memory and tick other components
    def [](index : Int) : UInt8
      # todo: not all of these registers are used. unused registers _should_ return 0xFF
      # - sound doesn't take all of 0xFF10..0xFF3F
      tick_components
      return 0xFF_u8 if (0 < @dma_position <= 0xA0) && OAM.includes?(index)
      read_byte index
    end

    # write a 8 bits to memory (doesn't tick components)
    def write_byte(index : Int, value : UInt8) : Nil
      if index == 0xFF50 && value == 0x11
        @bootrom = Bytes.new 0
        @cgb_ptr.value = @cartridge.cgb != Cartridge::CGB::NONE
      end
      case index
      when ROM_BANK_0   then @cartridge[index] = value
      when ROM_BANK_N   then @cartridge[index] = value
      when VRAM         then @ppu[index] = value
      when EXTERNAL_RAM then @cartridge[index] = value
      when WORK_RAM_0   then @wram[0][index - WORK_RAM_0.begin] = value
      when WORK_RAM_N   then @wram[@wram_bank][index - WORK_RAM_N.begin] = value
      when ECHO         then write_byte index - 0x2000, value
      when OAM          then @ppu[index] = value
      when NOT_USABLE   then nil
      when IO_PORTS
        case index
        when 0xFF00 then @joypad.write value
        when 0xFF01
          {% if flag? :print_serial %}
            print value
            STDOUT.flush
          {% elsif flag? :print_serial_ascii %}
            print value.chr
            STDOUT.flush
          {% end %}
        when 0xFF04..0xFF07 then @timer[index] = value
        when 0xFF0F         then @interrupts[index] = value
        when 0xFF10..0xFF3F then @apu[index] = value
        when 0xFF46         then dma_transfer value
        when 0xFF40..0xFF4B then @ppu[index] = value
        when 0xFF4D         then @requested_speed_switch = value & 0x1 > 0 if @cgb_ptr.value
        when 0xFF4F         then @ppu[index] = value
        when 0xFF51..0xFF55 then @ppu[index] = value
        when 0xFF68..0xFF6B then @ppu[index] = value
        when 0xFF70
          if @cgb_ptr.value
            @wram_bank = value & 0x7
            @wram_bank += 1 if @wram_bank == 0
          end
        when 0xFF72 then @ff72 = value
        when 0xFF73 then @ff73 = value
        when 0xFF74 then @ff74 = value if @cgb_ptr.value
        when 0xFF75 then @ff75 = value | 0x8F
        else             nil
        end
      when HRAM          then @hram[index - HRAM.begin] = value
      when INTERRUPT_REG then @interrupts[index] = value
      else                    raise "FAILED TO SET INDEX #{index}"
      end
    end

    # write 8 bits to memory and tick other components
    def []=(index : Int, value : UInt8) : Nil
      tick_components
      return if (0 < @dma_position <= 0xA0) && OAM.includes?(index)
      write_byte index, value
    end

    # write 16 bits to memory
    def []=(index : Int, value : UInt16) : Nil
      self[index + 1] = (value >> 8).to_u8
      self[index] = (value & 0xFF).to_u8
    end

    # read 16 bits from memory
    def read_word(index : Int) : UInt16
      self[index].to_u16 | (self[index + 1].to_u16 << 8)
    end

    def dma_transfer(source : UInt8) : Nil
      @dma = source
      @requested_oam_dma_transfer = true
      @next_dma_counter = 0
    end

    # DMA should start 8 T-cycles after a write to 0xFF46. That's what
    # `@requested_oam_dma_transfer` and `@next_dma_counter` are for. After that,
    # memory is still blocked for an additional 4 T-cycles, which is why I
    # increment `@dma_position` past 0xA0, even though it only transfers 0xA0
    # bytes. I just use it as an indicator of when memory should unlock again.
    # Note: According to a comment in gekkio's oam_dma_start test, if DMA is
    #       restarted while it has not yet completed, the 8 T-cycles should
    #       be spent continuing the first DMA rather than jumping to the new one.
    def dma_tick(cycles : Int) : Nil
      cycles.times do
        if @requested_oam_dma_transfer
          @next_dma_counter += 1
          if @next_dma_counter == 8
            @requested_oam_dma_transfer = false
            @current_dma_source = @dma.to_u16 << 8
            @dma_position = 0
            @internal_dma_timer = 0
          end
        end
        if @dma_position <= 0xA0
          if @internal_dma_timer & 3 == 0
            write_byte 0xFE00 + @dma_position, read_byte @current_dma_source + @dma_position if @dma_position < 0xA0
            @dma_position += 1
          end
          @internal_dma_timer += 1
        end
      end
    end
  end
end
