require "./gpio"

module GBA
  class Bus
    # Timings for rom are estimated for game compatibility.
    ACCESS_TIMING_TABLE = [
      [1, 1, 3, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2], # 8-bit and 16-bit accesses
      [1, 1, 6, 1, 1, 2, 2, 1, 4, 4, 4, 4, 4, 4, 4, 4], # 32-bit accesses
    ]
    property cycles = 0

    getter bios = Bytes.new 0x4000
    getter wram_board = Bytes.new 0x40000
    getter wram_chip = Bytes.new 0x08000

    @gpio : GPIO

    def initialize(@gba : GBA, bios_path : String)
      File.open(bios_path, &.read(@bios))
      @gpio = GPIO.new(@gba)
    end

    def [](address : UInt32) : UInt8
      @cycles += ACCESS_TIMING_TABLE[0][page(address)]
      read_byte_internal(address)
    end

    def read_half(address : UInt32) : UInt16
      @cycles += ACCESS_TIMING_TABLE[0][page(address)]
      read_half_internal(address)
    end

    def read_word(address : UInt32) : UInt32
      @cycles += ACCESS_TIMING_TABLE[1][page(address)]
      read_word_internal(address)
    end

    def []=(address : UInt32, value : UInt8) : Nil
      @cycles += ACCESS_TIMING_TABLE[0][page(address)]
      write_byte_internal(address, value)
    end

    def []=(address : UInt32, value : UInt16) : Nil
      @cycles += ACCESS_TIMING_TABLE[0][page(address)]
      write_half_internal(address, value)
    end

    def []=(address : UInt32, value : UInt32) : Nil
      @cycles += ACCESS_TIMING_TABLE[1][page(address)]
      write_word_internal(address, value)
    end

    def read_half_rotate(address : UInt32) : UInt32
      half = read_half(address).to_u32!
      bits = (address & 1) << 3
      half >> bits | half << (32 - bits)
    end

    # On ARM7 aka ARMv4 aka NDS7/GBA:
    #   LDRH Rd,[odd]   -->  LDRH Rd,[odd-1] ROR 8  ;read to bit0-7 and bit24-31
    #   LDRSH Rd,[odd]  -->  LDRSB Rd,[odd]         ;sign-expand BYTE value
    def read_half_signed(address : UInt32) : UInt32
      if bit?(address, 0)
        self[address].to_i8!.to_u32!
      else
        read_half(address).to_i16!.to_u32!
      end
    end

    def read_word_rotate(address : UInt32) : UInt32
      word = read_word address
      bits = (address & 3) << 3
      word >> bits | word << (32 - bits)
    end

    @[AlwaysInline]
    private def page(address : UInt32) : Int
      bits(address, 24..27)
    end

    @[AlwaysInline]
    private def read_byte_internal(address : UInt32) : UInt8
      case bits(address, 24..27)
      when 0x0 then @bios[address & 0x3FFF]
      when 0x1 then 0_u8 # todo: open bus
      when 0x2 then @wram_board[address & 0x3FFFF]
      when 0x3 then @wram_chip[address & 0x7FFF]
      when 0x4 then @gba.mmio[address]
      when 0x5 then @gba.ppu.pram[address & 0x3FF]
      when 0x6
        address = 0x1FFFF_u32 & address
        address -= 0x8000 if address > 0x17FFF
        @gba.ppu.vram[address]
      when 0x7 then @gba.ppu.oam[address & 0x3FF]
      when 0x8, 0x9, 0xA, 0xB, 0xC, 0xD
        if @gpio.address?(address) && @gpio.allow_reads
          @gpio[address]
        elsif @gba.storage.eeprom?(address)
          @gba.storage[address]
        else
          @gba.cartridge.rom[address & 0x01FFFFFF]
        end
      when 0xE, 0xF then @gba.storage[address]
      else               abort "Unmapped read: #{hex_str address.to_u32}"
      end
    end

    @[AlwaysInline]
    private def read_half_internal(address : UInt32) : UInt16
      address &= ~1
      case bits(address, 24..27)
      when 0x0 then (@bios.to_unsafe + (address & 0x3FFF)).as(UInt16*).value
      when 0x1 then 0_u16 # todo: open bus
      when 0x2 then (@wram_board.to_unsafe + (address & 0x3FFFF)).as(UInt16*).value
      when 0x3 then (@wram_chip.to_unsafe + (address & 0x7FFF)).as(UInt16*).value
      when 0x4 then read_half_internal_slow(address)
      when 0x5 then (@gba.ppu.pram.to_unsafe + (address & 0x3FF)).as(UInt16*).value
      when 0x6
        address = 0x1FFFF_u32 & address
        address -= 0x8000 if address > 0x17FFF
        (@gba.ppu.vram.to_unsafe + address).as(UInt16*).value
      when 0x7 then (@gba.ppu.oam.to_unsafe + (address & 0x3FF)).as(UInt16*).value
      when 0x8, 0x9, 0xA, 0xB, 0xC, 0xD
        if @gpio.address?(address) && @gpio.allow_reads
          @gpio[address].to_u16!
        elsif @gba.storage.eeprom?(address)
          @gba.storage[address].to_u16!
        else
          (@gba.cartridge.rom.to_unsafe + (address & 0x01FFFFFF)).as(UInt16*).value
        end
      when 0xE, 0xF then @gba.storage.read_half(address)
      else               abort "Unmapped read: #{hex_str address.to_u32}"
      end
    end

    @[AlwaysInline]
    private def read_word_internal(address : UInt32) : UInt32
      address &= ~3
      case bits(address, 24..27)
      when 0x0 then (@bios.to_unsafe + (address & 0x3FFF)).as(UInt32*).value
      when 0x1 then 0_u32 # todo: open bus
      when 0x2 then (@wram_board.to_unsafe + (address & 0x3FFFF)).as(UInt32*).value
      when 0x3 then (@wram_chip.to_unsafe + (address & 0x7FFF)).as(UInt32*).value
      when 0x4 then read_word_internal_slow(address)
      when 0x5 then (@gba.ppu.pram.to_unsafe + (address & 0x3FF)).as(UInt32*).value
      when 0x6
        address = 0x1FFFF_u32 & address
        address -= 0x8000 if address > 0x17FFF
        (@gba.ppu.vram.to_unsafe + address).as(UInt32*).value
      when 0x7 then (@gba.ppu.oam.to_unsafe + (address & 0x3FF)).as(UInt32*).value
      when 0x8, 0x9, 0xA, 0xB, 0xC, 0xD
        if @gpio.address?(address) && @gpio.allow_reads
          @gpio[address].to_u32!
        elsif @gba.storage.eeprom?(address)
          @gba.storage[address].to_u32!
        else
          (@gba.cartridge.rom.to_unsafe + (address & 0x01FFFFFF)).as(UInt32*).value
        end
      when 0xE, 0xF then @gba.storage.read_word(address)
      else               abort "Unmapped read: #{hex_str address.to_u32}"
      end
    end

    @[AlwaysInline]
    private def write_byte_internal(address : UInt32, value : UInt8) : Nil
      return if bits(address, 28..31) > 0
      @gba.cpu.fill_pipeline if address <= @gba.cpu.r[15] && address >= @gba.cpu.r[15] &- 4 # detect writes near pc
      case bits(address, 24..27)
      when 0x2 then @wram_board[address & 0x3FFFF] = value
      when 0x3 then @wram_chip[address & 0x7FFF] = value
      when 0x4 then @gba.mmio[address] = value
      when 0x5 then (@gba.ppu.pram.to_unsafe + (address & 0x3FE)).as(UInt16*).value = 0x0101_u16 * value
      when 0x6
        limit = @gba.ppu.bitmap? ? 0x13FFF : 0x0FFFF # (u8 write only) upper limit depends on display mode
        address = 0x1FFFE_u32 & address                # (u8 write only) UInt16-aligned
        address -= 0x8000 if address > 0x17FFF       # todo: determine if this happens before or after the limit check
        (@gba.ppu.vram.to_unsafe + address).as(UInt16*).value = 0x0101_u16 * value if address <= limit
      when 0x7      # can't write bytes to oam
      when 0x8, 0xD # all address between aren't writable
        if @gpio.address? address
          @gpio[address] = value
        elsif @gba.storage.eeprom? address
          @gba.storage[address]
        end
      when 0xE, 0xF then @gba.storage[address] = value
      else               log "Unmapped write: #{hex_str address.to_u32}"
      end
    end

    @[AlwaysInline]
    private def write_half_internal(address : UInt32, value : UInt16) : Nil
      return if bits(address, 28..31) > 0
      address &= ~1
      @gba.cpu.fill_pipeline if address <= @gba.cpu.r[15] && address >= @gba.cpu.r[15] &- 4 # detect writes near pc
      case bits(address, 24..27)
      when 0x2 then (@wram_board.to_unsafe + (address & 0x3FFFF)).as(UInt16*).value = value
      when 0x3 then (@wram_chip.to_unsafe + (address & 0x7FFF)).as(UInt16*).value = value
      when 0x4 then write_half_internal_slow(address, value)
      when 0x5 then (@gba.ppu.pram.to_unsafe + (address & 0x3FF)).as(UInt16*).value = value
      when 0x6
        address = 0x1FFFF_u32 & address
        address -= 0x8000 if address > 0x17FFF
        (@gba.ppu.vram.to_unsafe + address).as(UInt16*).value = value
      when 0x7 then (@gba.ppu.oam.to_unsafe + (address & 0x3FF)).as(UInt16*).value = value
      when 0x8, 0xD # all address between aren't writable
        if @gpio.address? address
          @gpio[address] = value.to_u8!
        elsif @gba.storage.eeprom? address
          @gba.storage[address] = value.to_u8!
        end
      when 0xE, 0xF then write_half_internal_slow(address, value)
      else               log "Unmapped write: #{hex_str address.to_u32}"
      end
    end

    @[AlwaysInline]
    private def write_word_internal(address : UInt32, value : UInt32) : Nil
      return if bits(address, 28..31) > 0
      address &= ~3
      @gba.cpu.fill_pipeline if address <= @gba.cpu.r[15] && address >= @gba.cpu.r[15] &- 4 # detect writes near pc
      case bits(address, 24..27)
      when 0x2 then (@wram_board.to_unsafe + (address & 0x3FFFF)).as(UInt32*).value = value
      when 0x3 then (@wram_chip.to_unsafe + (address & 0x7FFF)).as(UInt32*).value = value
      when 0x4 then write_word_internal_slow(address, value)
      when 0x5 then (@gba.ppu.pram.to_unsafe + (address & 0x3FF)).as(UInt32*).value = value
      when 0x6
        address = 0x1FFFF_u32 & address
        address -= 0x8000 if address > 0x17FFF
        (@gba.ppu.vram.to_unsafe + address).as(UInt32*).value = value
      when 0x7 then (@gba.ppu.oam.to_unsafe + (address & 0x3FF)).as(UInt32*).value = value
      when 0x8, 0xD # all address between aren't writable
        if @gpio.address? address
          @gpio[address] = value.to_u8!
        elsif @gba.storage.eeprom? address
          @gba.storage[address] = value.to_u8!
        end
      when 0xE, 0xF then write_word_internal_slow(address, value)
      else               log "Unmapped write: #{hex_str address.to_u32}"
      end
    end

    @[AlwaysInline]
    private def read_half_internal_slow(address : UInt32) : UInt16
      read_byte_internal(address).to_u16! |
        (read_byte_internal(address + 1).to_u16! << 8)
    end

    @[AlwaysInline]
    private def read_word_internal_slow(address : UInt32) : UInt32
      read_byte_internal(address).to_u32! |
        (read_byte_internal(address + 1).to_u32! << 8) |
        (read_byte_internal(address + 2).to_u32! << 16) |
        (read_byte_internal(address + 3).to_u32! << 24)
    end

    @[AlwaysInline]
    private def write_half_internal_slow(address : UInt32, value : UInt16) : Nil
      write_byte_internal(address, value.to_u8!)
      write_byte_internal(address + 1, (value >> 8).to_u8!)
    end

    @[AlwaysInline]
    private def write_word_internal_slow(address : UInt32, value : UInt32) : Nil
      write_byte_internal(address, value.to_u8!)
      write_byte_internal(address + 1, (value >> 8).to_u8!)
      write_byte_internal(address + 2, (value >> 16).to_u8!)
      write_byte_internal(address + 3, (value >> 24).to_u8!)
    end

    def read_open_bus_value(address : UInt32, _file = __FILE__) : UInt8
      log "Reading open bus at #{hex_str address.to_u32} from #{_file}"
      shift = (address & 3) * 8
      if @gba.cpu.cpsr.thumb
        # todo: special handling for 16-bit vs 32-bit regions
        # todo: does this need to have both of the previous opcodes?
        opcode = read_half_internal(@gba.cpu.r[15] & ~1).to_u32!
        word = opcode << 16 | opcode
      else
        word = read_word_internal(@gba.cpu.r[15] & ~3)
      end
      (word >> shift).to_u8!
    end
  end
end
