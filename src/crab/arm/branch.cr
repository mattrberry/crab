module ARM
  def arm_branch(instr : Word) : Nil
    link = bit?(instr, 24)
    offset = instr & 0xFFFFFF
    offset = (offset << 8).to_i32! >> 6
    set_reg(14, @r[15] - 4) if link
    set_reg(15, @r[15] &+ offset)
  end
end
