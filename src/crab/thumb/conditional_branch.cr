module THUMB
  def thumb_conditional_branch(instr : Word) : Nil
    cond = bits(instr, 8..11)
    offset = bits(instr, 0..7).to_i8!
    if cond
      @r[15] &+= (offset * 2)
      clear_pipeline
    end
  end
end
