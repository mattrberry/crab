module ARM
  def arm_multiply(instr : Word) : Nil
    accumulate = bit?(instr, 21)
    set_conditions = bit?(instr, 20)
    rd = bits(instr, 16..19)
    rn = bits(instr, 12..15)
    rs = bits(instr, 8..11)
    rm = bits(instr, 0..3)

    set_reg(rd, @r[rm] &* @r[rs])
    set_reg(rd, @r[rd] &+ @r[rn]) if accumulate
    set_neg_and_zero_flags(@r[rd]) if set_conditions
  end
end
