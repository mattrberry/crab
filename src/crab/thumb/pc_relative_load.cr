module THUMB
  macro thumb_pc_relative_load
    ->(gba : GBA, instr : Word) {
    imm = bits(instr, 0..7)
    rd = bits(instr, 8..10)
    gba.cpu.set_reg(rd, gba.bus.read_word((gba.cpu.r[15] & ~2) &+ (imm << 2)))
  }
  end
end
