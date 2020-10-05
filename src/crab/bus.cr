class Bus
  @wram_board = Bytes.new 0x40000
  @wram_chip = Bytes.new 0x08000

  def initialize(@gba : GBA)
  end

  def [](index : Int) : Byte
    log "read #{hex_str index.to_u32}"
    case bits(index, 24..27)
    when 0x2 then @wram_board[index & 0x3FFFF]
    when 0x3 then @wram_chip[index & 0x7FFF]
    when 0x4
      io_addr = 0x0FFF_u16 & index
      if io_addr <= 0x05F
        @gba.ppu[index]
      else
        raise "Unmapped i/o read: #{hex_str index.to_u32}"
      end
    when 0x6
      address = 0x1FFFF_u32 & index
      address &= ~0x8000 if address > 0x17FFF
      @gba.ppu.vram[address]
    when 0x8, 0x9 then @gba.cartridge[index & 0x7FFFFFF]
    else               raise "Unmapped read: #{hex_str index.to_u32}"
    end
  end

  def read_word(index : Int) : Word
    self[index].to_u32 |
      (self[index + 1].to_u32 << 8) |
      (self[index + 2].to_u32 << 16) |
      (self[index + 3].to_u32 << 24)
  end

  def read_half(index : Int) : Word
    self[index].to_u32 |
      (self[index + 1].to_u32 << 8)
  end

  def []=(index : Int, value : Byte) : Nil
    log "write #{hex_str index.to_u32} -> #{hex_str value}"
    return if bits(index, 28..31) > 0
    case bits(index, 24..27)
    when 0x2 then @wram_board[index & 0x3FFFF] = value
    when 0x3 then @wram_chip[index & 0x7FFF] = value
    when 0x4
      io_addr = 0x0FFF_u16 & index
      if io_addr <= 0x05F
        @gba.ppu[index] = value
      else
        raise "Unmapped i/o write: #{hex_str index.to_u32}"
      end
    when 0x6
      address = 0x1FFFF_u32 & index
      address &= ~0x8000 if address > 0x17FFF
      @gba.ppu.vram[address] = value
    when 0x8, 0x9 then @gba.cartridge[index & 0x7FFFFFF] = value
    else               raise "Unmapped write: #{hex_str index.to_u32}"
    end
  end

  def []=(index : Int, value : HalfWord) : Nil
    log "write #{hex_str index.to_u32} -> #{hex_str value}"
    self[index + 1] = 0xFF_u8 & (value >> 8)
    self[index] = 0xFF_u8 & value
  end

  def []=(index : Int, value : Word) : Nil
    log "write #{hex_str index.to_u32} -> #{hex_str value}"
    self[index + 3] = 0xFF_u8 & (value >> 24)
    self[index + 2] = 0xFF_u8 & (value >> 16)
    self[index + 1] = 0xFF_u8 & (value >> 8)
    self[index] = 0xFF_u8 & value
  end
end
