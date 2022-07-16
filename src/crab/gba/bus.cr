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
      File.open(bios_path) { |file| file.read @bios }
      @gpio = GPIO.new(@gba)
    end

    def [](index : Int) : Byte
      @cycles += ACCESS_TIMING_TABLE[0][page(index)]
      read_byte_internal(index)
    end

    def read_half(index : Int) : HalfWord
      @cycles += ACCESS_TIMING_TABLE[0][page(index)]
      read_half_internal(index)
    end

    def read_word(index : Int) : Word
      @cycles += ACCESS_TIMING_TABLE[1][page(index)]
      read_word_internal(index)
    end

    def []=(index : Int, value : Byte) : Nil
      @cycles += ACCESS_TIMING_TABLE[0][page(index)]
      write_byte_internal(index, value)
    end

    def []=(index : Int, value : HalfWord) : Nil
      @cycles += ACCESS_TIMING_TABLE[0][page(index)]
      write_half_internal(index, value)
    end

    def []=(index : Int, value : Word) : Nil
      @cycles += ACCESS_TIMING_TABLE[1][page(index)]
      write_word_internal(index, value)
    end

    def read_half_rotate(index : Int) : Word
      half = read_half(index).to_u32!
      bits = (index & 1) << 3
      half >> bits | half << (32 - bits)
    end

    # On ARM7 aka ARMv4 aka NDS7/GBA:
    #   LDRH Rd,[odd]   -->  LDRH Rd,[odd-1] ROR 8  ;read to bit0-7 and bit24-31
    #   LDRSH Rd,[odd]  -->  LDRSB Rd,[odd]         ;sign-expand BYTE value
    def read_half_signed(index : Int) : Word
      if bit?(index, 0)
        self[index].to_i8!.to_u32!
      else
        read_half(index).to_i16!.to_u32!
      end
    end

    def read_word_rotate(index : Int) : Word
      word = read_word index
      bits = (index & 3) << 3
      word >> bits | word << (32 - bits)
    end

    @[AlwaysInline]
    private def page(index : Int) : Int
      bits(index, 24..27)
    end

    @[AlwaysInline]
    private def read_byte_internal(index : Int) : Byte
      case bits(index, 24..27)
      when 0x0 then @bios[index & 0x3FFF]
      when 0x1 then 0_u8 # todo: open bus
      when 0x2 then @wram_board[index & 0x3FFFF]
      when 0x3 then @wram_chip[index & 0x7FFF]
      when 0x4 then @gba.mmio[index]
      when 0x5 then @gba.ppu.pram[index & 0x3FF]
      when 0x6
        address = 0x1FFFF_u32 & index
        address -= 0x8000 if address > 0x17FFF
        @gba.ppu.vram[address]
      when 0x7 then @gba.ppu.oam[index & 0x3FF]
      when 0x8, 0x9, 0xA, 0xB, 0xC, 0xD
        if @gpio.address?(index) && @gpio.allow_reads
          @gpio[index]
        elsif @gba.storage.eeprom?(index)
          @gba.storage[index]
        else
          @gba.cartridge.rom[index & 0x01FFFFFF]
        end
      when 0xE, 0xF then @gba.storage[index]
      else               abort "Unmapped read: #{hex_str index.to_u32}"
      end
    end

    @[AlwaysInline]
    private def read_half_internal(index : Int) : HalfWord
      index &= ~1
      case bits(index, 24..27)
      when 0x0 then (@bios.to_unsafe + (index & 0x3FFF)).as(HalfWord*).value
      when 0x1 then 0_u16 # todo: open bus
      when 0x2 then (@wram_board.to_unsafe + (index & 0x3FFFF)).as(HalfWord*).value
      when 0x3 then (@wram_chip.to_unsafe + (index & 0x7FFF)).as(HalfWord*).value
      when 0x4 then read_half_internal_slow(index)
      when 0x5 then (@gba.ppu.pram.to_unsafe + (index & 0x3FF)).as(HalfWord*).value
      when 0x6
        address = 0x1FFFF_u32 & index
        address -= 0x8000 if address > 0x17FFF
        (@gba.ppu.vram.to_unsafe + address).as(HalfWord*).value
      when 0x7 then (@gba.ppu.oam.to_unsafe + (index & 0x3FF)).as(HalfWord*).value
      when 0x8, 0x9, 0xA, 0xB, 0xC, 0xD
        if @gpio.address?(index) && @gpio.allow_reads
          @gpio[index].to_u16!
        elsif @gba.storage.eeprom?(index)
          @gba.storage[index].to_u16!
        else
          (@gba.cartridge.rom.to_unsafe + (index & 0x01FFFFFF)).as(HalfWord*).value
        end
      when 0xE, 0xF then @gba.storage.read_half(index)
      else               abort "Unmapped read: #{hex_str index.to_u32}"
      end
    end

    @[AlwaysInline]
    private def read_word_internal(index : Int) : Word
      index &= ~3
      case bits(index, 24..27)
      when 0x0 then (@bios.to_unsafe + (index & 0x3FFF)).as(Word*).value
      when 0x1 then 0_u32 # todo: open bus
      when 0x2 then (@wram_board.to_unsafe + (index & 0x3FFFF)).as(Word*).value
      when 0x3 then (@wram_chip.to_unsafe + (index & 0x7FFF)).as(Word*).value
      when 0x4 then read_word_internal_slow(index)
      when 0x5 then (@gba.ppu.pram.to_unsafe + (index & 0x3FF)).as(Word*).value
      when 0x6
        address = 0x1FFFF_u32 & index
        address -= 0x8000 if address > 0x17FFF
        (@gba.ppu.vram.to_unsafe + address).as(Word*).value
      when 0x7 then (@gba.ppu.oam.to_unsafe + (index & 0x3FF)).as(Word*).value
      when 0x8, 0x9, 0xA, 0xB, 0xC, 0xD
        if @gpio.address?(index) && @gpio.allow_reads
          @gpio[index].to_u32!
        elsif @gba.storage.eeprom?(index)
          @gba.storage[index].to_u32!
        else
          (@gba.cartridge.rom.to_unsafe + (index & 0x01FFFFFF)).as(Word*).value
        end
      when 0xE, 0xF then @gba.storage.read_word(index)
      else               abort "Unmapped read: #{hex_str index.to_u32}"
      end
    end

    @[AlwaysInline]
    private def write_byte_internal(index : Int, value : Byte) : Nil
      return if bits(index, 28..31) > 0
      @gba.cpu.fill_pipeline if index <= @gba.cpu.r[15] && index >= @gba.cpu.r[15] &- 4 # detect writes near pc
      case bits(index, 24..27)
      when 0x2 then @wram_board[index & 0x3FFFF] = value
      when 0x3 then @wram_chip[index & 0x7FFF] = value
      when 0x4 then @gba.mmio[index] = value
      when 0x5 then (@gba.ppu.pram.to_unsafe + (index & 0x3FE)).as(HalfWord*).value = 0x0101_u16 * value
      when 0x6
        limit = @gba.ppu.bitmap? ? 0x13FFF : 0x0FFFF # (u8 write only) upper limit depends on display mode
        address = 0x1FFFE_u32 & index                # (u8 write only) halfword-aligned
        address -= 0x8000 if address > 0x17FFF       # todo: determine if this happens before or after the limit check
        (@gba.ppu.vram.to_unsafe + address).as(HalfWord*).value = 0x0101_u16 * value if address <= limit
      when 0x7      # can't write bytes to oam
      when 0x8, 0xD # all address between aren't writable
        if @gpio.address? index
          @gpio[index] = value
        elsif @gba.storage.eeprom? index
          @gba.storage[index]
        end
      when 0xE, 0xF then @gba.storage[index] = value
      else               log "Unmapped write: #{hex_str index.to_u32}"
      end
    end

    @[AlwaysInline]
    private def write_half_internal(index : Int, value : HalfWord) : Nil
      return if bits(index, 28..31) > 0
      index &= ~1
      @gba.cpu.fill_pipeline if index <= @gba.cpu.r[15] && index >= @gba.cpu.r[15] &- 4 # detect writes near pc
      case bits(index, 24..27)
      when 0x2 then (@wram_board.to_unsafe + (index & 0x3FFFF)).as(HalfWord*).value = value
      when 0x3 then (@wram_chip.to_unsafe + (index & 0x7FFF)).as(HalfWord*).value = value
      when 0x4 then write_half_internal_slow(index, value)
      when 0x5 then (@gba.ppu.pram.to_unsafe + (index & 0x3FF)).as(HalfWord*).value = value
      when 0x6
        address = 0x1FFFF_u32 & index
        address -= 0x8000 if address > 0x17FFF
        (@gba.ppu.vram.to_unsafe + address).as(HalfWord*).value = value
      when 0x7 then (@gba.ppu.oam.to_unsafe + (index & 0x3FF)).as(HalfWord*).value = value
      when 0x8, 0xD # all address between aren't writable
        if @gpio.address? index
          @gpio[index] = value.to_u8!
        elsif @gba.storage.eeprom? index
          @gba.storage[index] = value.to_u8!
        end
      when 0xE, 0xF then write_half_internal_slow(index, value)
      else               log "Unmapped write: #{hex_str index.to_u32}"
      end
    end

    @[AlwaysInline]
    private def write_word_internal(index : Int, value : Word) : Nil
      return if bits(index, 28..31) > 0
      index &= ~3
      @gba.cpu.fill_pipeline if index <= @gba.cpu.r[15] && index >= @gba.cpu.r[15] &- 4 # detect writes near pc
      case bits(index, 24..27)
      when 0x2 then (@wram_board.to_unsafe + (index & 0x3FFFF)).as(Word*).value = value
      when 0x3 then (@wram_chip.to_unsafe + (index & 0x7FFF)).as(Word*).value = value
      when 0x4 then write_word_internal_slow(index, value)
      when 0x5 then (@gba.ppu.pram.to_unsafe + (index & 0x3FF)).as(Word*).value = value
      when 0x6
        address = 0x1FFFF_u32 & index
        address -= 0x8000 if address > 0x17FFF
        (@gba.ppu.vram.to_unsafe + address).as(Word*).value = value
      when 0x7 then (@gba.ppu.oam.to_unsafe + (index & 0x3FF)).as(Word*).value = value
      when 0x8, 0xD # all address between aren't writable
        if @gpio.address? index
          @gpio[index] = value.to_u8!
        elsif @gba.storage.eeprom? index
          @gba.storage[index] = value.to_u8!
        end
      when 0xE, 0xF then write_word_internal_slow(index, value)
      else               log "Unmapped write: #{hex_str index.to_u32}"
      end
    end

    @[AlwaysInline]
    private def read_half_internal_slow(index : Int) : HalfWord
      read_byte_internal(index).to_u16! |
        (read_byte_internal(index + 1).to_u16! << 8)
    end

    @[AlwaysInline]
    private def read_word_internal_slow(index : Int) : Word
      read_byte_internal(index).to_u32! |
        (read_byte_internal(index + 1).to_u32! << 8) |
        (read_byte_internal(index + 2).to_u32! << 16) |
        (read_byte_internal(index + 3).to_u32! << 24)
    end

    @[AlwaysInline]
    private def write_half_internal_slow(index : Int, value : HalfWord) : Nil
      write_byte_internal(index, value.to_u8!)
      write_byte_internal(index + 1, (value >> 8).to_u8!)
    end

    @[AlwaysInline]
    private def write_word_internal_slow(index : Int, value : Word) : Nil
      write_byte_internal(index, value.to_u8!)
      write_byte_internal(index + 1, (value >> 8).to_u8!)
      write_byte_internal(index + 2, (value >> 16).to_u8!)
      write_byte_internal(index + 3, (value >> 24).to_u8!)
    end
  end
end
