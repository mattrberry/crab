module THUMB
  def thumb_add_subtract(instr : Word) : Nil
    imm_flag = bit?(instr, 10)
    sub = bit?(instr, 9)
    imm = bits(instr, 6..8)
    rs = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    operand = if imm_flag
                imm
              else
                @r[imm]
              end
    if sub
      set_reg(rd, sub(@r[rs], operand, true))
    else
      set_reg(rd, add(@r[rs], operand, true))
    end
    set_neg_and_zero_flags(@r[rd])
  end
end
