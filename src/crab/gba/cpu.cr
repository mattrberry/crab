require "./arm/*"
require "./thumb/*"
require "./pipeline"
require "./waitloop"

module GBA
  class CPU
    include ARM
    include THUMB
    include Waitloop

    CLOCK_SPEED = 2**24

    enum Mode : UInt32
      USR = 0b10000
      FIQ = 0b10001
      IRQ = 0b10010
      SVC = 0b10011
      ABT = 0b10111
      UND = 0b11011
      SYS = 0b11111

      def bank : Int
        case self
        in Mode::USR, Mode::SYS then 0
        in Mode::FIQ            then 1
        in Mode::IRQ            then 2
        in Mode::SVC            then 3
        in Mode::ABT            then 4
        in Mode::UND            then 5
        end
      end
    end

    class PSR < BitField(UInt32)
      num mode, 5
      bool thumb
      bool fiq_disable
      bool irq_disable
      num reserved, 20
      bool overflow
      bool carry
      bool zero
      bool negative
    end

    getter r = Slice(UInt32).new 16
    getter cpsr : PSR = PSR.new CPU::Mode::SYS.value
    @spsr : PSR = PSR.new CPU::Mode::SYS.value
    getter pipeline = Pipeline.new
    getter lut : Slice(Proc(UInt32, Nil)) { fill_lut }
    getter thumb_lut : Slice(Proc(UInt32, Nil)) { fill_thumb_lut }
    @reg_banks = Slice(Slice(UInt32)).new 6 { Slice(UInt32).new 7, 0 }
    @spsr_banks = Slice(UInt32).new 6, CPU::Mode::SYS.value # logically independent of typical register banks
    property halted = false

    def initialize(@gba : GBA)
      clear_pipeline
    end

    def skip_bios : Nil
      @reg_banks[Mode::USR.bank][5] = @r[13] = 0x03007F00
      @reg_banks[Mode::IRQ.bank][5] = 0x03007FA0
      @reg_banks[Mode::SVC.bank][5] = 0x03007FE0
      @r[15] = 0x08000000
      clear_pipeline
    end

    def switch_mode(new_mode : Mode) : Nil
      old_mode = Mode.from_value @cpsr.mode
      return if new_mode == old_mode
      new_bank = new_mode.bank
      old_bank = old_mode.bank
      if new_mode == Mode::FIQ || old_mode == Mode::FIQ
        5.times do |idx|
          @reg_banks[old_bank][idx] = @r[8 + idx]
          @r[8 + idx] = @reg_banks[new_bank][idx]
        end
      end
      # store old regs
      @reg_banks[old_bank][5] = @r[13]
      @reg_banks[old_bank][6] = @r[14]
      @spsr_banks[old_bank] = @spsr.value
      # load new regs
      @r[13] = @reg_banks[new_bank][5]
      @r[14] = @reg_banks[new_bank][6]
      @spsr.value = @cpsr.value
      @cpsr.mode = new_mode.value
    end

    def irq : Nil
      unless @cpsr.irq_disable
        lr = @r[15] - (@cpsr.thumb ? 0 : 4)
        switch_mode CPU::Mode::IRQ
        @cpsr.thumb = false
        @cpsr.irq_disable = true
        set_reg(14, lr)
        set_reg(15, 0x18)
      end
    end

    def fill_pipeline : Nil
      if @cpsr.thumb
        pc = @r[15] & ~1
        @pipeline.push @gba.bus.read_half(pc &- 2).to_u32! if @pipeline.size == 0
        @pipeline.push @gba.bus.read_half(pc).to_u32! if @pipeline.size == 1
      else
        pc = @r[15] & ~3
        @pipeline.push @gba.bus.read_word(pc &- 4) if @pipeline.size == 0
        @pipeline.push @gba.bus.read_word(pc) if @pipeline.size == 1
      end
    end

    def clear_pipeline : Nil
      @pipeline.clear
      if @cpsr.thumb
        @r[15] &+= 4
      else
        @r[15] &+= 8
      end
    end

    def read_instr : UInt32
      if @pipeline.size == 0
        if @cpsr.thumb
          @r[15] &= ~1
          @gba.bus.read_half(@r[15] &- 4).to_u32!
        else
          @r[15] &= ~3
          @gba.bus.read_word(@r[15] &- 8)
        end
      else
        @pipeline.shift
      end
    end

    property count_cycles = 0

    def tick : Nil
      unless @halted
        instr = read_instr
        {% if flag? :trace %} print_state instr {% end %}
        if @cpsr.thumb
          thumb_execute instr
        else
          arm_execute instr
        end
        cycles, @gba.bus.cycles = @gba.bus.cycles, 0
        @count_cycles += cycles
        if @entered_waitloop
          @gba.scheduler.fast_forward
          @entered_waitloop = false
        else
          @gba.scheduler.tick cycles
        end
      else
        @gba.scheduler.fast_forward
      end
    end

    def check_cond(cond : UInt32) : Bool
      case cond
      when 0x0 then @cpsr.zero
      when 0x1 then !@cpsr.zero
      when 0x2 then @cpsr.carry
      when 0x3 then !@cpsr.carry
      when 0x4 then @cpsr.negative
      when 0x5 then !@cpsr.negative
      when 0x6 then @cpsr.overflow
      when 0x7 then !@cpsr.overflow
      when 0x8 then @cpsr.carry && !@cpsr.zero
      when 0x9 then !@cpsr.carry || @cpsr.zero
      when 0xA then @cpsr.negative == @cpsr.overflow
      when 0xB then @cpsr.negative != @cpsr.overflow
      when 0xC then !@cpsr.zero && @cpsr.negative == @cpsr.overflow
      when 0xD then @cpsr.zero || @cpsr.negative != @cpsr.overflow
      when 0xE then true
      else          raise "Cond 0xF is reserved"
      end
    end

    def step_arm : Nil
      @r[15] &+= 4
    end

    def step_thumb : Nil
      @r[15] &+= 2
    end

    @[AlwaysInline]
    def set_reg(reg : Int, value : UInt32) : UInt32
      @r[reg] = value
      clear_pipeline if reg == 15
      value
    end

    @[AlwaysInline]
    def set_neg_and_zero_flags(value : UInt32) : Nil
      @cpsr.negative = bit?(value, 31)
      @cpsr.zero = value == 0
    end

    # Logical shift left
    def lsl(word : UInt32, bits : Int::Unsigned, carry_out : Pointer(Bool)) : UInt32
      log "lsl - word:#{hex_str word}, bits:#{bits}"
      return word if bits == 0
      carry_out.value = bit?(word, 32 - bits)
      word << bits
    end

    # Logical shift right
    def lsr(word : UInt32, bits : Int::Unsigned, immediate : Bool, carry_out : Pointer(Bool)) : UInt32
      log "lsr - word:#{hex_str word}, bits:#{bits}"
      if bits == 0
        return word unless immediate
        bits = 32
      end
      carry_out.value = bit?(word, bits - 1)
      word >> bits
    end

    # Arithmetic shift right
    def asr(word : UInt32, bits : Int::Unsigned, immediate : Bool, carry_out : Pointer(Bool)) : UInt32
      log "asr - word:#{hex_str word}, bits:#{bits}"
      if bits == 0
        return word unless immediate
        bits = 32
      end
      if bits <= 31
        carry_out.value = bit?(word, bits - 1)
        word >> bits | (0xFFFFFFFF_u32 &* (word >> 31)) << (32 - bits)
      else
        # ASR by 32 or more has result filled with and carry out equal to bit 31 of Rm.
        carry_out.value = bit?(word, 31)
        0xFFFFFFFF_u32 &* (word >> 31)
      end
    end

    # Rotate right
    def ror(word : UInt32, bits : Int::Unsigned, immediate : Bool, carry_out : Pointer(Bool)) : UInt32
      log "ror - word:#{hex_str word}, bits:#{bits}"
      if bits == 0 # RRX #1
        return word unless immediate
        res = (word >> 1) | (@cpsr.carry.to_unsafe << 31)
        carry_out.value = bit?(word, 0)
        res
      else
        bits &= 31             # ROR by n where n is greater than 32 will give the same result and carry out as ROR by n-32
        bits = 32 if bits == 0 # ROR by 32 has result equal to Rm, carry out equal to bit 31 of Rm.
        carry_out.value = bit?(word, bits - 1)
        word >> bits | word << (32 - bits)
      end
    end

    # Subtract two values
    def sub(operand_1 : UInt32, operand_2 : UInt32, set_conditions : Bool) : UInt32
      log "sub - operand_1:#{hex_str operand_1}, operand_2:#{hex_str operand_2}"
      res = operand_1 &- operand_2
      if set_conditions
        set_neg_and_zero_flags(res)
        @cpsr.carry = operand_1 >= operand_2
        @cpsr.overflow = bit?((operand_1 ^ operand_2) & (operand_1 ^ res), 31)
      end
      res
    end

    # Subtract two values with carry
    def sbc(operand_1 : UInt32, operand_2 : UInt32, set_conditions : Bool) : UInt32
      log "sbc - operand_1:#{hex_str operand_1}, operand_2:#{hex_str operand_2}"
      res = operand_1 &- operand_2 &- 1 &+ @cpsr.carry.to_unsafe
      if set_conditions
        set_neg_and_zero_flags(res)
        @cpsr.carry = operand_1 >= operand_2.to_u64 + 1 - @cpsr.carry.to_unsafe
        @cpsr.overflow = bit?((operand_1 ^ operand_2) & (operand_1 ^ res), 31)
      end
      res
    end

    # Add two values
    def add(operand_1 : UInt32, operand_2 : UInt32, set_conditions : Bool) : UInt32
      log "add - operand_1:#{hex_str operand_1}, operand_2:#{hex_str operand_2}"
      res = operand_1 &+ operand_2
      if set_conditions
        set_neg_and_zero_flags(res)
        @cpsr.carry = res < operand_1
        @cpsr.overflow = bit?(~(operand_1 ^ operand_2) & (operand_2 ^ res), 31)
      end
      res
    end

    # Add two values with carry
    def adc(operand_1 : UInt32, operand_2 : UInt32, set_conditions : Bool) : UInt32
      log "adc - operand_1:#{hex_str operand_1}, operand_2:#{hex_str operand_2}"
      res = operand_1 &+ operand_2 &+ @cpsr.carry.to_unsafe
      if set_conditions
        set_neg_and_zero_flags(res)
        @cpsr.carry = res < operand_1.to_u64 + @cpsr.carry.to_unsafe
        @cpsr.overflow = bit?(~(operand_1 ^ operand_2) & (operand_2 ^ res), 31)
      end
      res
    end

    def print_state(instr : UInt32? = nil) : Nil
      @r.each_with_index do |val, reg|
        print "#{hex_str reg == 15 ? val - (@cpsr.thumb ? 2 : 4) : val, prefix: false} "
      end
      instr ||= @pipeline.peek
      if @cpsr.thumb
        puts "cpsr: #{hex_str @cpsr.value, prefix: false} |     #{hex_str instr.to_u16, prefix: false}"
      else
        puts "cpsr: #{hex_str @cpsr.value, prefix: false} | #{hex_str instr, prefix: false}"
      end
    end
  end
end
