module THUMB
  macro thumb_add_subtract
    ->(gba : GBA, instr : Word) {
    imm_flag = bit?(instr, 10)
    sub = bit?(instr, 9)
    imm = bits(instr, 6..8)
    rs = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    operand = if imm_flag
                imm
              else
                gba.cpu.r[imm]
              end
    if sub
      gba.cpu.set_reg(rd, gba.cpu.sub(gba.cpu.r[rs], operand, true))
    else
      gba.cpu.set_reg(rd, gba.cpu.add(gba.cpu.r[rs], operand, true))
    end
    gba.cpu.set_neg_and_zero_flags(gba.cpu.r[rd])
  }
  end
end
