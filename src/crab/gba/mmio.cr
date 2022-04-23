module GBA
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
      io_addr = 0xFFFFFF_u32 & index
      if io_addr <= 0x05F
        @gba.ppu.read_io io_addr
      elsif io_addr <= 0xAF
        @gba.apu.read_io io_addr
      elsif io_addr <= 0xFF
        @gba.dma.read_io io_addr
      elsif 0x100 <= io_addr <= 0x10F
        @gba.timer.read_io io_addr
      elsif 0x130 <= io_addr <= 0x133
        @gba.keypad.read_io io_addr
      elsif 0x120 <= io_addr <= 0x12F || 0x134 <= io_addr <= 0x1FF
        # todo: serial
        0_u8
      elsif 0x200 <= io_addr <= 0x203 || 0x208 <= io_addr <= 0x209
        @gba.interrupts.read_io io_addr
      elsif 0x204 <= io_addr <= 0x205
        (@waitcnt.value >> (8 * (io_addr & 1))).to_u8!
      else
        0_u8 # todo: oob reads
      end
    end

    def []=(index : Int, value : Byte) : Nil
      io_addr = 0xFFFFFF_u32 & index
      if io_addr <= 0x05F
        @gba.ppu.write_io io_addr, value
      elsif io_addr <= 0xAF
        @gba.apu.write_io io_addr, value
      elsif io_addr <= 0xFF
        @gba.dma.write_io io_addr, value
      elsif 0x100 <= io_addr <= 0x10F
        @gba.timer.write_io io_addr, value
      elsif 0x130 <= io_addr <= 0x133
        @gba.keypad.read_io io_addr
      elsif 0x120 <= io_addr <= 0x12F || 0x134 <= io_addr <= 0x1FF
        # todo: serial
      elsif 0x200 <= io_addr <= 0x203 || 0x208 <= io_addr <= 0x209
        @gba.interrupts.write_io io_addr, value
      elsif 0x204 <= io_addr <= 0x205
        shift = 8 * (io_addr & 1)
        mask = 0xFF00_u16 >> shift
        @waitcnt.value = (@waitcnt.value & mask) | value.to_u16 << shift
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
