class MMIO
  def initialize(@gba : GBA)
  end

  def [](index : Int) : Byte
    io_addr = 0x0FFF_u16 & index
    if io_addr <= 0x05F
      @gba.ppu.read_io io_addr
    elsif (io_addr >= 0x200 && io_addr <= 0x203) || (io_addr >= 0x208 && io_addr <= 0x209)
      @gba.interrupts.read_io io_addr
    elsif io_addr >= 0x130 && io_addr <= 0x133 # todo keypad
      0xFF_u8
    elsif not_used? io_addr
      0xFF_u8 # todo what is returned here?
    else
      raise "Unmapped MMIO read: #{hex_str index.to_u32}"
    end
  end

  def []=(index : Int, value : Byte) : Nil
    io_addr = 0x0FFF_u16 & index
    if io_addr <= 0x05F
      @gba.ppu.write_io io_addr, value
    elsif (io_addr >= 0x200 && io_addr <= 0x203) || (io_addr >= 0x208 && io_addr <= 0x209)
      @gba.interrupts.write_io io_addr, value
    elsif not_used? io_addr
    else
      raise "Unmapped MMIO write: #{hex_str index.to_u32}"
    end
  end

  def not_used?(io_addr : Int) : Bool
    (0x0E0..0x0FE).includes?(io_addr) || (0x110..0x11E).includes?(io_addr) ||
      (0x12C..0x12E).includes?(io_addr) || (0x138..0x13E).includes?(io_addr) ||
      (0x142..0x14E).includes?(io_addr) || (0x15A..0x1FE).includes?(io_addr) ||
      0x206 == io_addr || (0x20A..0x2FF).includes?(io_addr) ||
      (0x302..0x40F).includes?(io_addr) || (0x441..0x7FF).includes?(io_addr) ||
      (0x804..0xFFFF).includes?(io_addr)
  end
end
