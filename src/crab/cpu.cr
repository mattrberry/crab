require "./arm/*"
require "./thumb/*"

class CPU
  include ARM
  include THUMB

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
  @cpsr : PSR
  @pipeline = Deque(Word).new 2
  getter lut : Slice(Proc(Word, Nil)) { fill_lut }
  getter thumb_lut : Slice(Proc(Word, Nil)) { fill_thumb_lut }

  def initialize(@gba : GBA)
    @r[0] = 0x08000000
    @r[1] = 0x000000EA
    @r[13] = 0x03007F00
    @r[15] = 0x08000000
    @cpsr = PSR.new 0x6000001F
  end

  def fill_pipeline : Nil
    while @pipeline.size < 2
      if @cpsr.thumb
        log "Fetch pc: #{hex_str @r[15]}, instr: #{hex_str @gba.bus.read_half(@r[15]).to_u16}"
        @pipeline << @gba.bus.read_half @r[15]
        @r[15] &+= 2
      else
        log "Fetch pc: #{hex_str @r[15]}, instr: #{hex_str @gba.bus.read_word @r[15]}"
        @pipeline << @gba.bus.read_word @r[15]
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
    @cpsr.carry = bit?(word, 32 - bits) if set_conditions
    word << bits
  end

  # Logical shift right
  def lsr(word : Word, bits : Int, set_conditions : Bool) : Word
    log "lsr - word:#{hex_str word}, bits:#{bits}"
    @cpsr.carry = bit?(word, bits - 1) if set_conditions
    word >> bits
  end

  # Arithmetic shift right
  def asr(word : Word, bits : Int, set_conditions : Bool) : Word
    log "asr - word:#{hex_str word}, bits:#{bits}"
    @cpsr.carry = bit?(word, bits - 1) if set_conditions
    word // (2 ** bits)
  end

  # Rotate right
  def ror(word : Word, bits : Int, set_conditions : Bool) : Word
    log "ror - word:#{hex_str word}, bits:#{bits}"
    @cpsr.carry = bit?(word, bits - 1) if set_conditions
    word >> bits | word << (32 - bits)
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
