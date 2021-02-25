class Bus
  getter bios = Bytes.new 0x4000
  getter wram_board = Bytes.new 0x40000
  getter wram_chip = Bytes.new 0x08000

  def initialize(@gba : GBA, bios_path : String)
    File.open(bios_path) { |file| file.read @bios }
  end

  def [](index : Int) : Byte
    case bits(index, 24..27)
    when 0x0 then @bios[index & 0x3FFF]
    when 0x2 then @wram_board[index & 0x3FFFF]
    when 0x3 then @wram_chip[index & 0x7FFF]
    when 0x4 then @gba.mmio[index]
    when 0x5 then @gba.ppu.pram[index & 0x3FF]
    when 0x6
      address = 0x1FFFF_u32 & index
      address -= 0x8000 if address > 0x17FFF
      @gba.ppu.vram[address]
    when 0x7 then @gba.ppu.oam[index & 0x3FF]
    when 0x8, 0x9,
         0xA, 0xB,
         0xC, 0xD then @gba.cartridge.rom[index & 0x01FFFFFF]
    when 0xE, 0xF then @gba.storage[index]
    else               abort "Unmapped read: #{hex_str index.to_u32}"
    end
  end

  def read_half(index : Int) : HalfWord
    index &= ~1
    case bits(index, 24..27)
    when 0x0 then (@bios.to_unsafe + (index & 0x3FFF)).as(HalfWord*).value
    when 0x2 then (@wram_board.to_unsafe + (index & 0x3FFFF)).as(HalfWord*).value
    when 0x3 then (@wram_chip.to_unsafe + (index & 0x7FFF)).as(HalfWord*).value
    when 0x4 then read_half_slow(index)
    when 0x5 then (@gba.ppu.pram.to_unsafe + (index & 0x3FF)).as(HalfWord*).value
    when 0x6
      address = 0x1FFFF_u32 & index
      address -= 0x8000 if address > 0x17FFF
      (@gba.ppu.vram.to_unsafe + address).as(HalfWord*).value
    when 0x7 then (@gba.ppu.oam.to_unsafe + (index & 0x3FF)).as(HalfWord*).value
    when 0x8, 0x9,
         0xA, 0xB,
         0xC, 0xD then (@gba.cartridge.rom.to_unsafe + (index & 0x01FFFFFF)).as(HalfWord*).value
    when 0xE, 0xF then read_half_slow(index)
    else               abort "Unmapped read: #{hex_str index.to_u32}"
    end
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

  def read_word(index : Int) : Word
    index &= ~3
    case bits(index, 24..27)
    when 0x0 then (@bios.to_unsafe + (index & 0x3FFF)).as(Word*).value
    when 0x2 then (@wram_board.to_unsafe + (index & 0x3FFFF)).as(Word*).value
    when 0x3 then (@wram_chip.to_unsafe + (index & 0x7FFF)).as(Word*).value
    when 0x4 then read_word_slow(index)
    when 0x5 then (@gba.ppu.pram.to_unsafe + (index & 0x3FF)).as(Word*).value
    when 0x6
      address = 0x1FFFF_u32 & index
      address -= 0x8000 if address > 0x17FFF
      (@gba.ppu.vram.to_unsafe + address).as(Word*).value
    when 0x7 then (@gba.ppu.oam.to_unsafe + (index & 0x3FF)).as(Word*).value
    when 0x8, 0x9,
         0xA, 0xB,
         0xC, 0xD then (@gba.cartridge.rom.to_unsafe + (index & 0x01FFFFFF)).as(Word*).value
    when 0xE, 0xF then read_word_slow(index)
    else               abort "Unmapped read: #{hex_str index.to_u32}"
    end
  end

  def read_word_rotate(index : Int) : Word
    word = read_word index
    bits = (index & 3) << 3
    word >> bits | word << (32 - bits)
  end

  def []=(index : Int, value : Byte) : Nil
    return if bits(index, 28..31) > 0
    @gba.cpu.fill_pipeline if index <= @gba.cpu.r[15] && index >= @gba.cpu.r[15] &- 4 # detect writes near pc
    case bits(index, 24..27)
    when 0x2 then @wram_board[index & 0x3FFFF] = value
    when 0x3 then @wram_chip[index & 0x7FFF] = value
    when 0x4 then @gba.mmio[index] = value
    when 0x5 then @gba.ppu.pram[index & 0x3FF] = value
    when 0x6
      address = 0x1FFFF_u32 & index
      address -= 0x8000 if address > 0x17FFF
      @gba.ppu.vram[address] = value
    when 0x7      then @gba.ppu.oam[index & 0x3FF] = value
    when 0xE, 0xF then @gba.storage[index] = value
    else               log "Unmapped write: #{hex_str index.to_u32}"
    end
  end

  def []=(index : Int, value : HalfWord) : Nil
    return if bits(index, 28..31) > 0
    index &= ~1
    @gba.cpu.fill_pipeline if index <= @gba.cpu.r[15] && index >= @gba.cpu.r[15] &- 4 # detect writes near pc
    case bits(index, 24..27)
    when 0x2 then (@wram_board.to_unsafe + (index & 0x3FFFF)).as(HalfWord*).value = value
    when 0x3 then (@wram_chip.to_unsafe + (index & 0x7FFF)).as(HalfWord*).value = value
    when 0x4 then write_half_slow(index, value)
    when 0x5 then (@gba.ppu.pram.to_unsafe + (index & 0x3FF)).as(HalfWord*).value = value
    when 0x6
      address = 0x1FFFF_u32 & index
      address -= 0x8000 if address > 0x17FFF
      (@gba.ppu.vram.to_unsafe + address).as(HalfWord*).value = value
    when 0x7      then (@gba.ppu.oam.to_unsafe + (index & 0x3FF)).as(HalfWord*).value = value
    when 0xE, 0xF then write_half_slow(index, value)
    else               log "Unmapped write: #{hex_str index.to_u32}"
    end
  end

  def []=(index : Int, value : Word) : Nil
    return if bits(index, 28..31) > 0
    index &= ~3
    @gba.cpu.fill_pipeline if index <= @gba.cpu.r[15] && index >= @gba.cpu.r[15] &- 4 # detect writes near pc
    case bits(index, 24..27)
    when 0x2 then (@wram_board.to_unsafe + (index & 0x3FFFF)).as(Word*).value = value
    when 0x3 then (@wram_chip.to_unsafe + (index & 0x7FFF)).as(Word*).value = value
    when 0x4 then write_word_slow(index, value)
    when 0x5 then (@gba.ppu.pram.to_unsafe + (index & 0x3FF)).as(Word*).value = value
    when 0x6
      address = 0x1FFFF_u32 & index
      address -= 0x8000 if address > 0x17FFF
      (@gba.ppu.vram.to_unsafe + address).as(Word*).value = value
    when 0x7      then (@gba.ppu.oam.to_unsafe + (index & 0x3FF)).as(Word*).value = value
    when 0xE, 0xF then write_word_slow(index, value)
    else               log "Unmapped write: #{hex_str index.to_u32}"
    end
  end

  private def read_half_slow(index : Int) : HalfWord
    self[index].to_u16! |
      (self[index + 1].to_u16! << 8)
  end

  private def read_word_slow(index : Int) : Word
    self[index].to_u32! |
      (self[index + 1].to_u32! << 8) |
      (self[index + 2].to_u32! << 16) |
      (self[index + 3].to_u32! << 24)
  end

  private def write_half_slow(index : Int, value : HalfWord) : Nil
    self[index] = value.to_u8!
    self[index + 1] = (value >> 8).to_u8!
  end

  private def write_word_slow(index : Int, value : Word) : Nil
    self[index] = value.to_u8!
    self[index + 1] = (value >> 8).to_u8!
    self[index + 2] = (value >> 16).to_u8!
    self[index + 3] = (value >> 24).to_u8!
  end
end
