module THUMB
  def thumb_add_offset_to_stack_pointer(instr : Word) : Nil
    sign = bit?(instr, 7)
    offset = bits(instr, 0..6)
    if sign # negative
      set_reg(13, @r[13] &- (offset << 2))
    else # positive
      set_reg(13, @r[13] &+ (offset << 2))
    end

    step_thumb
  end
end
