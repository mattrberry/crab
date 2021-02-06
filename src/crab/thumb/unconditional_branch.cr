module THUMB
  macro thumb_unconditional_branch
    ->(gba : GBA, instr : Word) {
    offset = bits(instr, 0..10)
    offset = (offset << 5).to_i16! >> 4
    gba.cpu.set_reg(15, gba.cpu.r[15] &+ offset)
  }
  end
end
