module THUMB
  def thumb_long_branch_link(instr : Word) : Nil
    second_instr = bit?(instr, 11)
    offset = bits(instr, 0..10)
    if second_instr
      @r[14] &+= (offset << 1)
      @r[15], @r[14] = @r[14], @r[15] - 1
      clear_pipeline
    else
      offset = (offset << 5).to_i16! >> 5 # todo make this just bit math
      @r[14] = @r[15] &+ (offset << 12)
    end
  end
end
