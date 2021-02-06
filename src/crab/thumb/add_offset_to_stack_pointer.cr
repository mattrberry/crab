module THUMB
  macro thumb_add_offset_to_stack_pointer
    ->(gba : GBA, instr : Word) {
    sign = bit?(instr, 7)
    offset = bits(instr, 0..6)
    if sign # negative
      gba.cpu.set_reg(13, gba.cpu.r[13] &- (offset << 2))
    else # positive
      gba.cpu.set_reg(13, gba.cpu.r[13] &+ (offset << 2))
    end
  }
  end
end
