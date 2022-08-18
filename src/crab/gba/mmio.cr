module GBA
  class MMIO
    @waitcnt = Reg::WAITCNT.new 0

    def initialize(@gba : GBA)
    end

    def [](index : Int) : Byte
      io_addr = 0xFFFFFF_u32 & index
      if io_addr <= 0x05F
        @gba.ppu[io_addr]
      elsif io_addr <= 0xAF
        @gba.apu[io_addr]
      elsif io_addr <= 0xFF
        @gba.dma[io_addr]
      elsif 0x100 <= io_addr <= 0x10F
        @gba.timer[io_addr]
      elsif 0x130 <= io_addr <= 0x133
        @gba.keypad[io_addr]
      elsif 0x120 <= io_addr <= 0x12F || 0x134 <= io_addr <= 0x1FF
        # todo: serial
        if io_addr == 0x135
          0x80_u8
        else
          0_u8
        end
      elsif 0x200 <= io_addr <= 0x203 || 0x208 <= io_addr <= 0x209
        @gba.interrupts[io_addr]
      elsif 0x204 <= io_addr <= 0x205
        @waitcnt.read_byte(io_addr & 1)
      else
        0_u8 # todo: oob reads
      end
    end

    def []=(index : Int, value : Byte) : Nil
      io_addr = 0xFFFFFF_u32 & index
      if io_addr <= 0x05F
        @gba.ppu[io_addr] = value
      elsif io_addr <= 0xAF
        @gba.apu[io_addr] = value
      elsif io_addr <= 0xFF
        @gba.dma[io_addr] = value
      elsif 0x100 <= io_addr <= 0x10F
        @gba.timer[io_addr] = value
      elsif 0x130 <= io_addr <= 0x133
        @gba.keypad[io_addr]
      elsif 0x120 <= io_addr <= 0x12F || 0x134 <= io_addr <= 0x1FF
        # todo: serial
      elsif 0x200 <= io_addr <= 0x203 || 0x208 <= io_addr <= 0x209
        @gba.interrupts[io_addr] = value
      elsif 0x204 <= io_addr <= 0x205
        @waitcnt.write_byte(io_addr & 1, value)
      elsif io_addr == 0x301
        if bit?(value, 7)
          abort "Stopping not supported"
        else
          @gba.cpu.halted = true
        end
      end
    end
  end
end
