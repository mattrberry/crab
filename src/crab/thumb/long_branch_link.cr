module THUMB
  def thumb_long_branch_link(instr : Word) : Nil
    second_instr = bit?(instr, 11)
    offset = bits(instr, 0..10)
    if second_instr
      temp = @r[15] &- 2
      @r[15] = @r[14] &+ (offset << 1)
      @r[14] = temp | 1
      clear_pipeline
    else
      offset = (offset << 5).to_i16! >> 5
      @r[14] = @r[15] &+ (offset.to_u32 << 12)
    end
  end
end
