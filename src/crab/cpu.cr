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
    when 0x0 then bit? @cpsr, 30                                            # Z
    when 0x1 then !bit? @cpsr, 30                                           # !Z
    when 0x2 then bit? @cpsr, 29                                            # C
    when 0x3 then !bit? @cpsr, 29                                           # !C
    when 0x4 then bit? @cpsr, 31                                            # N
    when 0x5 then !bit? @cpsr, 31                                           # !N
    when 0x6 then bit? @cpsr, 28                                            # V
    when 0x7 then !bit? @cpsr, 28                                           # !V
    when 0x8 then (bit? @cpsr, 29) && (!bit? @cpsr, 30)                     # C && !Z
    when 0x9 then (!bit? @cpsr, 29) || (bit? @cpsr, 30)                     # !C || Z
    when 0xA then (bit? @cpsr, 31) == (bit? @cpsr, 28)                      # N == V
    when 0xB then (bit? @cpsr, 31) != (bit? @cpsr, 28)                      # N != V
    when 0xC then (!bit? @cpsr, 30) && (bit? @cpsr, 31) == (bit? @cpsr, 28) # !Z && N == V
    when 0xD then (bit? @cpsr, 30) || (bit? @cpsr, 31) != (bit? @cpsr, 28)  # Z || N != V
    when 0xE then true                                                      # always
    else          raise "Cond 0xF is reserved"                              # reserved
    end
  end

  def tick : Nil
    fill_pipeline
    instr = @pipeline.shift
    execute instr
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
        link = bit? instr, 24
        offset = instr & 0xFFFFFF
        offset = (~offset &+ 1).to_i32 if bit? offset, 23 # negative
        offset <<= 2
        @r[14] = @r[15] - 4 if link
        @r[15] &+= offset
        clear_pipeline
      else raise "Unimplemented execution of type: #{instr_type}"
      end
    else
      puts "Skipping instruction, cond: #{hex_str instr >> 28}"
    end
  end
end
