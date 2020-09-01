class CPU
  @r = Slice(Word).new 16
  @cpsr : UInt32 = 0
  @pipeline = Deque(Word).new 2

  def initialize(@gba : GBA)
    @r[15] = 0x08000000
  end

  def fill_pipeline : Nil
    while @pipeline.size < 2
      puts "Fetch pc: #{hex_str @r[15]}, instr: #{hex_str @gba.bus.read_word @r[15]}, type: #{Instr.from_hash hash_instr @gba.bus.read_word @r[15]}"
      @pipeline << @gba.bus.read_word @r[15]
      @r[15] &+= 4
    end
  end

  def clear_pipeline : Nil
    puts "Clearing pipeline"
    @pipeline.clear
  end

  def check_cond(cond : Int) : Bool
    case 0xF_u8 & cond & 0xF
    when 0x0 then bit?(@cpsr, 30)                                        # Z
    when 0x1 then !bit?(@cpsr, 30)                                       # !Z
    when 0x2 then bit?(@cpsr, 29)                                        # C
    when 0x3 then !bit?(@cpsr, 29)                                       # !C
    when 0x4 then bit?(@cpsr, 31)                                        # N
    when 0x5 then !bit?(@cpsr, 31)                                       # !N
    when 0x6 then bit?(@cpsr, 28)                                        # V
    when 0x7 then !bit?(@cpsr, 28)                                       # !V
    when 0x8 then bit?(@cpsr, 29) && !bit?(@cpsr, 30)                    # C && !Z
    when 0x9 then !bit?(@cpsr, 29) || bit?(@cpsr, 30)                    # !C || Z
    when 0xA then bit?(@cpsr, 31) == bit?(@cpsr, 28)                     # N == V
    when 0xB then bit?(@cpsr, 31) != bit?(@cpsr, 28)                     # N != V
    when 0xC then !bit?(@cpsr, 30) && bit?(@cpsr, 31) == bit?(@cpsr, 28) # !Z && N == V
    when 0xD then bit?(@cpsr, 30) || bit?(@cpsr, 31) != bit?(@cpsr, 28)  # Z || N != V
    when 0xE then true                                                   # always
    else          raise "Cond 0xF is reserved"
    end
  end

  def tick : Nil
    fill_pipeline
    instr = @pipeline.shift
    execute instr
  end

  # Logical shift left
  def lsl(word : Word, bits : Int) : Word
    word << bits
  end

  # Logical shift right
  def lsr(word : Word, bits : Int) : Word
    word >> bits
  end

  # Arithmetic shift right
  def asr(word : Word, bits : Int) : Word
    word // (2 ** bits)
  end

  # Rotate right
  def ror(word : Word, bits : Int) : Word
    word >> bits | word << (32 - bits)
  end

  def hash_instr(instr : Word) : Word
    ((instr >> 16) & 0x0FF0) | ((instr >> 4) & 0xF)
  end

  def execute(instr : Word) : Nil
    if check_cond instr >> 28
      hash = hash_instr instr
      instr_type = Instr.from_hash hash
      puts "Execute #{hex_str instr}: #{instr_type}"
      case instr_type
      when Instr::BRANCH
        link = bit?(instr, 24)
        offset = instr & 0xFFFFFF
        offset = (~offset &+ 1).to_i32 if bit?(offset, 23) # negative
        offset <<= 2
        @r[14] = @r[15] - 4 if link
        @r[15] &+= offset
        clear_pipeline
      when Instr::DATA_PROCESSING_PSR_TRANSFER
        # todo all resulting flags
        imm_flag = bit?(instr, 25)
        opcode = bits(instr, 21..24)
        set_conditions = bit?(instr, 20)
        rn = bits(instr, 16..19)
        rd = bits(instr, 12..15)
        operand_2 = if imm_flag # Operand 2 is an immediate
                      rotate = bits(instr, 8..11)
                      imm = bits(instr, 0..7)
                      ror(imm, 2 * rotate)
                    else # Operand 2 is a register
                      shift = bits(instr, 4..11)
                      reg = bits(instr, 0..3)
                      shift_type = bits(instr, 5..6)
                      shift_amount = if bit?(instr, 4)
                                       shift_register = bits(instr, 8..11)
                                       @r[shift_register] & 0xF
                                     else
                                       bits(instr, 7..11)
                                     end
                      case shift_type
                      when 0b00 then lsl(reg, shift_amount)
                      when 0b01 then lsr(reg, shift_amount)
                      when 0b10 then asr(reg, shift_amount)
                      when 0b11 then ror(reg, shift_amount)
                      else           raise "Impossible shift type: #{hex_str shift_type}"
                      end
                    end
        case opcode
        when 0x0 then @r[rd] = rn & operand_2
        when 0x1 then @r[rd] = rn ^ operand_2
        when 0x2 then @r[rd] = rn &- operand_2
        when 0x3 then @r[rd] = operand_2 &- rn
        when 0x4 then @r[rd] = rn &+ operand_2
        when 0x5 then @r[rd] = rn &+ operand_2 &+ (bit?(@cpsr, 29) ? 1 : 0)
        when 0x6 then @r[rd] = rn &- operand_2 &+ (bit?(@cpsr, 29) ? 1 : 0) &- 1
        when 0x7 then @r[rd] = operand_2 &- rn &+ (bit?(@cpsr, 29) ? 1 : 0) &- 1
        when 0x8
        when 0x9
        when 0xA
        when 0xB
        when 0xC then @r[rd] = rn | operand_2
        when 0xD then @r[rd] = operand_2
        when 0xE then @r[rd] = rn & ~operand_2
        when 0xF then @r[rd] = ~operand_2
        else          raise "Unimplemented execution of data processing opcode: #{hex_str opcode}"
        end
      else raise "Unimplemented execution of type: #{instr_type}"
      end
    else
      puts "Skipping instruction, cond: #{hex_str instr >> 28}"
    end
  end
end
