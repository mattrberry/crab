class CPU
  @r = Slice(Word).new 16
  @pipeline = Deque(Word).new 2

  def initialize(@gba : GBA)
    @r[15] = 0x08000000
  end

  def fill_pipeline : Nil
    while @pipeline.size < 2
      puts "FETCH PC: #{hex_str @r[15]}, INSTR: #{hex_str @gba.bus.read_word @r[15]}, TYPE: #{Instr.from_hash hash_instr @gba.bus.read_word @r[15]}"
      @pipeline << @gba.bus.read_word @r[15]
      @r[15] &+= 4
    end
  end

  def clear_pipeline : Nil
    @pipeline.clear
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
    cond = true
    if cond
      hash = hash_instr instr
      instr_type = Instr.from_hash hash
      case instr_type
      when Instr::BRANCH
        puts "EXECUTE BRANCH"
        link = bit? instr, 24
        offset = instr & 0xFFFFFF
        offset = (~offset &+ 1).to_i32 if bit? offset, 23 # negative
        offset <<= 2
        @r[14] = @r[15] - 4 if link
        @r[15] &+= offset
        @pipeline.clear
      else raise "Unimplemented execution of type: #{instr_type}"
      end
    end
  end
end
