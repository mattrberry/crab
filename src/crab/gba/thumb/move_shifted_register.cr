module GBA
  module THUMB
    def thumb_move_shifted_register(instr : Word) : Nil
      op = bits(instr, 11..12)
      offset = bits(instr, 6..10)
      rs = bits(instr, 3..5)
      rd = bits(instr, 0..2)
      carry_out = @cpsr.carry
      case op
      when 0b00 then set_reg(rd, lsl(@r[rs], offset, pointerof(carry_out)))
      when 0b01 then set_reg(rd, lsr(@r[rs], offset, true, pointerof(carry_out)))
      when 0b10 then set_reg(rd, asr(@r[rs], offset, true, pointerof(carry_out)))
      when 0b11 # encodes thumb add/subtract
      else raise "Invalid shifted register op: #{op}"
      end
      set_neg_and_zero_flags(@r[rd])
      @cpsr.carry = carry_out

      step_thumb
    end
  end
end
