class CPU
  @registers = Slice(UInt32).new 16

  def initialize(@gba : GBA)
    self.pc = 0x08000000
  end

  def pc : Word
    @registers[15]
  end

  def pc=(pc : Word) : Nil
    @registers[15] = pc
  end

  def tick : Nil
    puts "PC: #{hex_str pc}, INSTRUCTION: #{hex_str @gba.bus.read_word pc}, TYPE: #{Instr.from_hash hash_instr @gba.bus.read_word pc}"
    # puts hex_str @gba.bus.read_word pc
    # puts hex_str hash_instr @gba.bus.read_word pc
    # puts Instr.from_hash hash_instr @gba.bus.read_word pc
    self.pc += 4
  end

  def hash_instr(instr : Word) : Word
    ((instr >> 16) & 0x0FF0) | ((instr >> 4) & 0xF)
  end
end
