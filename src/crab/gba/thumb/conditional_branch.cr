module GBA
  module THUMB
    def thumb_conditional_branch(instr : UInt32) : Nil
      cond = bits(instr, 8..11)
      offset = bits(instr, 0..7).to_i8!.to_i32
      if check_cond cond
        set_reg(15, @r[15] &+ (offset * 2))
      else
        step_thumb
      end
    end
  end
end
