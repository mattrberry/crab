module GBA
  class MMIO
    @waitcnt = Reg::WAITCNT.new 0

    def initialize(@gba : GBA)
    end

    def [](address : UInt32) : UInt8
      io_addr = 0xFFFFFF_u32 & address
      case io_addr
      when 0x000..0x055 then @gba.ppu[io_addr]
      when 0x060..0x0A7 then @gba.apu[io_addr]
      when 0x0B0..0x0DF then @gba.dma[io_addr]
      when 0x100..0x10F then @gba.timer[io_addr]
      when 0x120..0x12B, 0x134..0x15B # todo: serial
        if io_addr == 0x135
          0x80_u8
        else
          0_u8
        end
      when 0x130..0x133 then @gba.keypad[io_addr]
      when 0x200..0x203,
           0x208..0x209 then @gba.interrupts[io_addr]
      when 0x204..0x205 then @waitcnt.read_byte(io_addr & 1)
      when 0x206..0x207,
           0x20A..0x20B,
           0x302..0x303 then 0_u8 # do not read open bus
      else @gba.bus.read_open_bus_value(io_addr)
      end
    end

    def []=(address : UInt32, value : UInt8) : Nil
      io_addr = 0xFFFFFF_u32 & address
      case io_addr
      when 0x000..0x055 then @gba.ppu[io_addr] = value
      when 0x060..0x0A7 then @gba.apu[io_addr] = value
      when 0x0B0..0x0DF then @gba.dma[io_addr] = value
      when 0x100..0x10F then @gba.timer[io_addr] = value
      when 0x120..0x12B, 0x134..0x15B # todo: serial
      when 0x130..0x133 then @gba.keypad[io_addr] = value
      when 0x200..0x203,
           0x208..0x209 then @gba.interrupts[io_addr] = value
      when 0x204..0x205 then @waitcnt.write_byte(io_addr & 1, value)
      when 0x301
        if bit?(value, 7)
          # TODO: See about supporting some kind of stopping
        else
          @gba.cpu.halted = true
        end
      end
    end
  end
end
