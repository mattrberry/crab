module GBA
  module ARM
    def arm_multiply(instr : Word) : Nil
      accumulate = bit?(instr, 21)
      set_conditions = bit?(instr, 20)
      rd = bits(instr, 16..19)
      rn = bits(instr, 12..15)
      rs = bits(instr, 8..11)
      rm = bits(instr, 0..3)

      set_reg(rd, @r[rm] &* @r[rs] &+ (accumulate ? @r[rn] : 0))
      set_neg_and_zero_flags(@r[rd]) if set_conditions

      step_arm unless rd == 15
    end
  end
end
