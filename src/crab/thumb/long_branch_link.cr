module THUMB
  macro thumb_long_branch_link
    ->(gba : GBA, instr : Word) {
    second_instr = bit?(instr, 11)
    offset = bits(instr, 0..10)
    if second_instr
      temp = gba.cpu.r[15] &- 2
      gba.cpu.set_reg(15, gba.cpu.r[14] &+ (offset << 1))
      gba.cpu.set_reg(14, temp | 1)
    else
      offset = (offset << 5).to_i16! >> 5
      gba.cpu.set_reg(14, gba.cpu.r[15] &+ (offset.to_u32! << 12))
    end
  }
  end
end
