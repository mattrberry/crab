class Interrupts
  class InterruptReg < BitField(UInt16)
    num not_used, 2, lock: true
    bool game_pak
    bool keypad
    bool dma3
    bool dma2
    bool dma1
    bool dma0
    bool serial
    bool timer3
    bool timer2
    bool timer1
    bool timer0
    bool vcounter
    bool hblank
    bool vblank
  end

  getter reg_ie : InterruptReg = InterruptReg.new 0
  getter reg_if : InterruptReg = InterruptReg.new 0
  getter ime : Bool = false

  def initialize(@gba : GBA)
  end

  def read_io(io_addr : Int) : Byte
    case io_addr
    when 0x200 then 0xFF_u8 & @reg_ie.value
    when 0x201 then 0xFF_u8 & @reg_ie.value >> 8
    when 0x202 then 0xFF_u8 & @reg_if.value
    when 0x203 then 0xFF_u8 & @reg_if.value >> 8
    when 0x208 then @ime ? 1_u8 : 0_u8
    when 0x209 then 0_u8
    else            raise "Unimplemented interrupts read ~ addr:#{hex_str io_addr.to_u8!}"
    end
  end

  def write_io(io_addr : Int, value : Byte) : Nil
    case io_addr
    when 0x200 then @reg_ie.value = (@reg_ie.value & 0xFF00) | value
    when 0x201 then @reg_ie.value = (@reg_ie.value & 0x00FF) | value.to_u16 << 8
    when 0x202 then @reg_if.value &= ~value
    when 0x203 then @reg_if.value &= ~(value.to_u16 << 8)
    when 0x208 then @ime = bit?(value, 0)
    when 0x209 # ignored
    else raise "Unimplemented interrupts write ~ addr:#{hex_str io_addr.to_u8!}, val:#{value}"
    end
    schedule_interrupt_check
  end

  def schedule_interrupt_check : Nil
    @gba.scheduler.schedule 0, ->check_interrupts
  end

  private def check_interrupts : Nil
    if @reg_ie.value & @reg_if.value != 0
      @gba.cpu.halted = false
      @gba.cpu.irq if @ime
    end
  end
end
