module GBA
  module ARM
    def arm_branch(instr : UInt32) : Nil
      link = bit?(instr, 24)
      offset = (bits(instr, 0..23) << 8).to_i32! >> 6
      set_reg(14, @r[15] - 4) if link
      set_reg(15, @r[15] &+ offset)
    end
  end
end
