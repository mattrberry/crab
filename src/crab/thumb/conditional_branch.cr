module THUMB
  macro thumb_conditional_branch
    ->(gba : GBA, instr : Word) {
    cond = bits(instr, 8..11)
    offset = bits(instr, 0..7).to_i8!.to_i32
    if gba.cpu.check_cond cond
      gba.cpu.set_reg(15, gba.cpu.r[15] &+ (offset * 2))
    end
  }
  end
end
