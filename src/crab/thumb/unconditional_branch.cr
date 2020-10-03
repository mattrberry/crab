module THUMB
  def thumb_unconditional_branch(instr : Word) : Nil
    offset = bits(instr, 0..10)
    offset = (offset << 5).to_i16! >> 4
    @r[15] &+= offset
    clear_pipeline
  end
end
