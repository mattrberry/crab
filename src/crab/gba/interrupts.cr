module GBA
  class Interrupts
    getter reg_ie = Reg::InterruptReg.new 0
    getter reg_if = Reg::InterruptReg.new 0
    getter ime : Bool = false

    def initialize(@gba : GBA)
    end

    def [](io_addr : Int) : Byte
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

    def []=(io_addr : Int, value : Byte) : Nil
      case io_addr
      when 0x200 then @reg_ie.value = (@reg_ie.value & 0xFF00) | value
      when 0x201 then @reg_ie.value = (@reg_ie.value & 0x00FF) | value.to_u16 << 8
      when 0x202 then @reg_if.value &= ~value.to_u16
      when 0x203 then @reg_if.value &= ~(value.to_u16 << 8)
      when 0x208 then @ime = bit?(value, 0)
      when 0x209 # ignored
      else raise "Unimplemented interrupts write ~ addr:#{hex_str io_addr.to_u8!}, val:#{value}"
      end
      schedule_interrupt_check
    end

    def schedule_interrupt_check : Nil
      @gba.scheduler.schedule 0, ->check_interrupts, Scheduler::EventType::Interrupts
    end

    private def check_interrupts : Nil
      if @reg_ie.value & @reg_if.value != 0
        @gba.cpu.halted = false
        # puts "IE:#{hex_str @reg_ie.value} & IF:#{hex_str @reg_if.value} != 0"
        @gba.cpu.irq if @ime
      end
    end
  end
end
