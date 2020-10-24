require "./arm/*"
require "./thumb/*"
require "./pipeline"

class CPU
  include ARM
  include THUMB

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
    bool negative
    bool zero
    bool carry
    bool overflow
    num reserved, 20
    bool irq_disable
    bool fiq_disable
    bool thumb
    num mode, 5
  end

  @r = Slice(Word).new 16
  @cpsr : PSR = PSR.new 0x0000001F
  @spsr : PSR = PSR.new 0
  @pipeline = Pipeline.new
  getter lut : Slice(Proc(Word, Nil)) { fill_lut }
  getter thumb_lut : Slice(Proc(Word, Nil)) { fill_thumb_lut }
  @reg_banks = Array(Array(Word)).new 6 { Array(Word).new 8, 0 }

  def initialize(@gba : GBA)
    @r[0] = 0x08000000
    @r[1] = 0x000000EA
    @reg_banks[Mode::USR.bank][5] = @r[13] = 0x03007F00
    @reg_banks[Mode::IRQ.bank][5] = 0x03007FA0
    @reg_banks[Mode::SVC.bank][5] = 0x03007FE0
    @r[15] = 0x08000000
    @cpsr = PSR.new 0x6000001F
  end

  def switch_mode(new_mode : Mode) : Nil
    old_mode = Mode.from_value @cpsr.mode
    return if new_mode == old_mode
    @cpsr.mode = new_mode.value
    new_bank = new_mode.bank
    old_bank = old_mode.bank
    if new_bank == 0
      @spsr.value = @cpsr.value
    else
      @spsr.value = @reg_banks[new_bank][7]
    end
    if new_mode == Mode::FIQ || old_mode == Mode::FIQ
      5.times do |idx|
        @reg_banks[old_bank][idx] = @r[8 + idx]
        @r[8 + idx] = @reg_banks[new_bank][idx]
      end
    end
    # store old regs
    @reg_banks[old_bank][5] = @r[13]
    @reg_banks[old_bank][6] = @r[14]
    # load new regs
    @r[13] = @reg_banks[new_bank][5]
    @r[14] = @reg_banks[new_bank][6]
  end

  def fill_pipeline : Nil
    while @pipeline.size < 2
      if @cpsr.thumb
        log "Fetch pc: #{hex_str @r[15]}, instr: #{hex_str @gba.bus.read_half(@r[15]).to_u16}"
        @pipeline.push @gba.bus.read_half @r[15]
        @r[15] &+= 2
      else
        log "Fetch pc: #{hex_str @r[15]}, instr: #{hex_str @gba.bus.read_word @r[15]}"
        @pipeline.push @gba.bus.read_word @r[15]
        @r[15] &+= 4
      end
    end
  end

  def clear_pipeline : Nil
    log "Clearing pipeline"
    @pipeline.clear
  end

  def tick : Nil
    fill_pipeline
    instr = @pipeline.shift
    print_state instr
    if @cpsr.thumb
      thumb_execute instr
    else
      arm_execute instr
    end
    @gba.tick 1
  end

  def check_cond(cond : Word) : Bool
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

  # Logical shift left
  def lsl(word : Word, bits : Int, set_conditions : Bool) : Word
    log "lsl - word:#{hex_str word}, bits:#{bits}"
    return word if bits == 0
    @cpsr.carry = bit?(word, 32 - bits) if set_conditions
    word << bits
  end

  # Logical shift right
  def lsr(word : Word, bits : Int, set_conditions : Bool) : Word
    log "lsr - word:#{hex_str word}, bits:#{bits}"
    return word if bits == 0
    @cpsr.carry = bit?(word, bits - 1) if set_conditions
    word >> bits
  end

  # Arithmetic shift right
  def asr(word : Word, bits : Int, set_conditions : Bool) : Word
    log "asr - word:#{hex_str word}, bits:#{bits}"
    return word if bits == 0
    if bits <= 31
      @cpsr.carry = bit?(word, bits - 1) if set_conditions
      word >> bits | (0xFFFFFFFF_u32 &* (word >> 31)) << (32 - bits)
    else
      # ASR by 32 or more has result filled with and carry out equal to bit 31 of Rm.
      @cpsr.carry = bit?(word, 31) if set_conditions
      0xFFFFFFFF_u32 &* (word >> 31)
    end
  end

  # Rotate right
  def ror(word : Word, bits : Int, set_conditions : Bool) : Word
    log "ror - word:#{hex_str word}, bits:#{bits}"
    return word if bits == 0
    bits &= 31
    if bits == 0
      # ROR by 32 has result equal to Rm, carry out equal to bit 31 of Rm.
      @cpsr.carry = bit?(word, 31) if set_conditions
      word
    else
      @cpsr.carry = bit?(word, bits - 1) if set_conditions
      word >> bits | word << (32 - bits)
    end
  end

  # Subtract two values
  def sub(operand_1 : Word, operand_2 : Word, set_conditions) : Word
    log "sub - operand_1:#{hex_str operand_1}, operand_2:#{hex_str operand_2}"
    res = operand_1 &- operand_2
    if set_conditions
      @cpsr.overflow = bit?((operand_1 ^ operand_2) & (operand_1 ^ res), 31)
      @cpsr.carry = operand_1 >= operand_2
      @cpsr.zero = res == 0
      @cpsr.negative = bit?(res, 31)
    end
    res
  end

  # Subtract two values with carry
  def sbc(operand_1 : Word, operand_2 : Word, set_conditions) : Word
    log "sbc - operand_1:#{hex_str operand_1}, operand_2:#{hex_str operand_2}"
    res = operand_1 &- operand_2 &+ @cpsr.carry.to_unsafe &- 1
    if set_conditions
      @cpsr.overflow = bit?((operand_1 ^ operand_2) & (operand_1 ^ res), 31)
      @cpsr.carry = operand_1 >= operand_2
      @cpsr.zero = res == 0
      @cpsr.negative = bit?(res, 31)
    end
    res
  end

  # Add two values
  def add(operand_1 : Word, operand_2 : Word, set_conditions) : Word
    log "add - operand_1:#{hex_str operand_1}, operand_2:#{hex_str operand_2}"
    res = operand_1 &+ operand_2
    if set_conditions
      @cpsr.overflow = bit?(~(operand_1 ^ operand_2) & (operand_2 ^ res), 31)
      @cpsr.carry = res < operand_1
      @cpsr.zero = res == 0
      @cpsr.negative = bit?(res, 31)
    end
    res
  end

  # Add two values with carry
  def adc(operand_1 : Word, operand_2 : Word, set_conditions) : Word
    log "adc - operand_1:#{hex_str operand_1}, operand_2:#{hex_str operand_2}"
    res = operand_1 &+ operand_2 &+ @cpsr.carry.to_unsafe
    if set_conditions
      @cpsr.overflow = bit?(~(operand_1 ^ operand_2) & (operand_2 ^ res), 31)
      @cpsr.carry = res < operand_1.to_u64 + @cpsr.carry.to_unsafe
      @cpsr.zero = res == 0
      @cpsr.negative = bit?(res, 31)
    end
    res
  end

  def print_state(instr : Word) : Nil
    {% if flag? :trace %}
      @r.each do |reg|
        trace "#{hex_str reg, prefix: false} ", newline: false
      end
      if @cpsr.thumb
        trace "cpsr: #{hex_str @cpsr.value, prefix: false} |     #{hex_str instr.to_u16, prefix: false}"
      else
        trace "cpsr: #{hex_str @cpsr.value, prefix: false} | #{hex_str instr, prefix: false}"
      end
    {% end %}
  end
end
