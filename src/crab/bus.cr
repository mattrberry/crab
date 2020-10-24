class Bus
  @bios = Bytes.new 0x3FFF
  @wram_board = Bytes.new 0x40000
  @wram_chip = Bytes.new 0x08000

  def initialize(@gba : GBA, bios_path : String)
    File.open(bios_path) { |file| file.read @bios }
  end

  def [](index : Int) : Byte
    log "read #{hex_str index.to_u32}"
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
    when 0x7      then @gba.ppu.oam[index & 0x3FF]
    when 0x8, 0x9 then @gba.cartridge[index & 0x7FFFFFF]
    else               raise "Unmapped read: #{hex_str index.to_u32}"
    end
  end

  def read_half(index : Int) : Word
    puts "Unaligned half read at #{hex_str index.to_u32}" if index.to_u32 != index.to_u32 & 0xFFFFFFFE
    self[index].to_u32 |
      (self[index + 1].to_u32 << 8)
  end

  def read_word(index : Int) : Word
    puts "Unaligned word read at #{hex_str index.to_u32}" if index.to_u32 != index.to_u32 & 0xFFFFFFFC
    self[index].to_u32 |
      (self[index + 1].to_u32 << 8) |
      (self[index + 2].to_u32 << 16) |
      (self[index + 3].to_u32 << 24)
  end

  def []=(index : Int, value : Byte) : Nil
    log "write #{hex_str index.to_u32} -> #{hex_str value}"
    return if bits(index, 28..31) > 0
    case bits(index, 24..27)
    when 0x0 then puts "Writing to bios - #{hex_str index.to_u32}: #{hex_str value}"
    when 0x2 then @wram_board[index & 0x3FFFF] = value
    when 0x3 then @wram_chip[index & 0x7FFF] = value
    when 0x4 then @gba.mmio[index] = value
    when 0x5 then @gba.ppu.pram[index & 0x3FF] = value
    when 0x6
      address = 0x1FFFF_u32 & index
      address -= 0x8000 if address > 0x17FFF
      @gba.ppu.vram[address] = value
    when 0x7 then @gba.ppu.oam[index & 0x3FF]
    when 0x8, 0x9 then @gba.cartridge[index & 0x7FFFFFF] = value
    else               raise "Unmapped write: #{hex_str index.to_u32}"
    end
  end

  def []=(index : Int, value : HalfWord) : Nil
    puts "Unaligned half write at #{hex_str index.to_u32}: #{hex_str value}" if index.to_u32 != index.to_u32 & 0xFFFFFFFE
    self[index] = 0xFF_u8 & value
    self[index + 1] = 0xFF_u8 & (value >> 8)
  end

  def []=(index : Int, value : Word) : Nil
    puts "Unaligned word write at #{hex_str index.to_u32}: #{hex_str value}" if index.to_u32 != index.to_u32 & 0xFFFFFFFC
    self[index] = 0xFF_u8 & value
    self[index + 1] = 0xFF_u8 & (value >> 8)
    self[index + 2] = 0xFF_u8 & (value >> 16)
    self[index + 3] = 0xFF_u8 & (value >> 24)
  end
end
