class MMIO
  class WAITCNT < BitField(UInt16)
    bool gamepak_type, lock: true
    bool gamepack_prefetch_buffer
    bool not_used, lock: true
    num phi_terminal_output, 2
    num wait_state_2_second_access, 1
    num wait_state_2_first_access, 2
    num wait_state_1_second_access, 1
    num wait_state_1_first_access, 2
    num wait_state_0_second_access, 1
    num wait_state_0_first_access, 2
    num sram_wait_control, 2
  end

  @waitcnt = WAITCNT.new 0

  def initialize(@gba : GBA)
  end

  def [](index : Int) : Byte
    io_addr = 0x0FFF_u16 & index
    if io_addr <= 0x05F
      @gba.ppu.read_io io_addr
    elsif (io_addr >= 0x200 && io_addr <= 0x203) || (io_addr >= 0x208 && io_addr <= 0x209)
      @gba.interrupts.read_io io_addr
    elsif io_addr >= 0x130 && io_addr <= 0x133
      @gba.keypad.read_io io_addr
    elsif io_addr >= 0x204 && io_addr <= 0x205
      (@waitcnt.value >> (8 * (io_addr & 1))).to_u8!
    elsif not_used? io_addr
      0xFF_u8 # todo what is returned here?
    else
      puts "Unmapped MMIO read: #{hex_str index.to_u32}".colorize(:red)
      0_u8
    end
  end

  def []=(index : Int, value : Byte) : Nil
    io_addr = 0x0FFF_u16 & index
    if io_addr <= 0x05F
      @gba.ppu.write_io io_addr, value
    elsif (io_addr >= 0x200 && io_addr <= 0x203) || (io_addr >= 0x208 && io_addr <= 0x209)
      @gba.interrupts.write_io io_addr, value
    elsif io_addr >= 0x130 && io_addr <= 0x133
      @gba.keypad.read_io io_addr
    elsif io_addr >= 0x204 && io_addr <= 0x205
      shift = 8 * (io_addr & 1)
      mask = 0xFF00_u16 >> shift
      @waitcnt.value = (@waitcnt.value & mask) | value.to_u16 << shift
    elsif io_addr == 0x301
      @gba.cpu.halted = bit?(value, 7)
    elsif not_used? io_addr
    else
      puts "Unmapped MMIO write ~ addr:#{hex_str index.to_u32}, val:#{hex_str value}".colorize(:yellow)
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
