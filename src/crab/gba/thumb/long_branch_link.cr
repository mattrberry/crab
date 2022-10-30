module GBA
  module THUMB
    def thumb_long_branch_link(instr : UInt32) : Nil
      second_instr = bit?(instr, 11)
      offset = bits(instr, 0..10)
      if second_instr
        temp = @r[15] &- 2
        set_reg(15, @r[14] &+ (offset << 1))
        set_reg(14, temp | 1)
      else
        offset = (offset << 5).to_i16! >> 5
        set_reg(14, @r[15] &+ (offset.to_u32! << 12))
        step_thumb
      end
    end
  end
end
