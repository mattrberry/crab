module ARM
  def arm_branch(instr : Word) : Nil
    link = bit?(instr, 24)
    offset = instr & 0xFFFFFF
    offset = (offset << 8).to_i32! >> 6
    @r[14] = @r[15] - 4 if link
    @r[15] &+= offset
    clear_pipeline
  end
end
