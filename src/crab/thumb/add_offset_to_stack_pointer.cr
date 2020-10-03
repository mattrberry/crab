module THUMB
  def thumb_add_offset_to_stack_pointer(instr : Word) : Nil
    sign = bit?(instr, 7)
    offset = bits(instr, 0..6)
    if sign # negative
      @r[13] &-= (offset << 2)
    else # positive
      @r[13] &+= (offset << 2)
    end
  end
end
