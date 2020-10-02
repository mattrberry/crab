class Bus
  WRAM_BOARD   = 0x02000000..0x0203FFFF
  WRAM_CHIP    = 0x03000000..0x03007FFF
  PPU_IO       = 0x04000000..0x0400005F
  SOUND_IO     = 0x04000060..0x040000AF
  DMA_IO       = 0x040000B0..0x040000FF
  TIMER_IO     = 0x04000100..0x0400011F
  SERIAL_IO_1  = 0x04000120..0x0400012F
  KEYPAD_IO    = 0x04000130..0x04000133
  SERIAL_IO_2  = 0x04000134..0x040001FF
  INTERRUPT_IO = 0x04000200..0x0400FFFF
  CARTRIDGE    = 0x08000000..0x0FFFFFFF
  UNUSED       = 0x10000000..0xFFFFFFFF

  @wram_board = Bytes.new Bus::WRAM_BOARD.size
  @wram_chip = Bytes.new Bus::WRAM_CHIP.size

  def initialize(@gba : GBA)
  end

  def [](index : Int) : Byte
    log "read #{hex_str index.to_u32}"
    case index
    when WRAM_BOARD then @wram_board[index - WRAM_BOARD.begin]
    when WRAM_CHIP  then @wram_chip[index - WRAM_CHIP.begin]
    when PPU_IO then @gba.ppu[index]
    when CARTRIDGE  then @gba.cartridge[index - CARTRIDGE.begin]
    when UNUSED     then 0xFF
    else                 0xFF
    end.to_u8
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
    case index
    when WRAM_BOARD then @wram_board[index - WRAM_BOARD.begin] = value
    when WRAM_CHIP  then @wram_chip[index - WRAM_CHIP.begin] = value
    when PPU_IO then @gba.ppu[index] = value
    when CARTRIDGE  then @gba.cartridge[index - CARTRIDGE.begin] = value # todo is this meant to be writable?
    when UNUSED     then nil
    else                 raise "Unimplemented write ~ addr:#{hex_str index.to_u32}, val:#{value}"
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
