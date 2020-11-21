module THUMB
  def thumb_alu_operations(instr : Word) : Nil
    op = bits(instr, 6..9)
    rs = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    barrel_shifter_carry_out = @cpsr.carry
    case op
    when 0b0000 then res = set_reg(rd, @r[rd] & @r[rs])
    when 0b0001 then res = set_reg(rd, @r[rd] ^ @r[rs])
    when 0b0010
      res = set_reg(rd, lsl(@r[rd], @r[rs], pointerof(barrel_shifter_carry_out)))
      @cpsr.carry = barrel_shifter_carry_out
    when 0b0011
      res = set_reg(rd, lsr(@r[rd], @r[rs], false, pointerof(barrel_shifter_carry_out)))
      @cpsr.carry = barrel_shifter_carry_out
    when 0b0100
      res = set_reg(rd, asr(@r[rd], @r[rs], false, pointerof(barrel_shifter_carry_out)))
      @cpsr.carry = barrel_shifter_carry_out
    when 0b0101 then res = set_reg(rd, adc(@r[rd], @r[rs], set_conditions: true))
    when 0b0110 then res = set_reg(rd, sbc(@r[rd], @r[rs], set_conditions: true))
    when 0b0111
      res = set_reg(rd, ror(@r[rd], @r[rs], false, pointerof(barrel_shifter_carry_out)))
      @cpsr.carry = barrel_shifter_carry_out
    when 0b1000 then res = @r[rd] & @r[rs]
    when 0b1001 then res = set_reg(rd, (-@r[rs].to_i32!).to_u32!)
    when 0b1010 then res = sub(@r[rd], @r[rs], set_conditions: true)
    when 0b1011 then res = add(@r[rd], @r[rs], set_conditions: true)
    when 0b1100 then res = set_reg(rd, @r[rd] | @r[rs])
    when 0b1101 then res = set_reg(rd, @r[rs] &* @r[rd])
    when 0b1110 then res = set_reg(rd, @r[rd] & ~@r[rs])
    when 0b1111 then res = set_reg(rd, ~@r[rs])
    else             raise "Invalid alu op: #{op}"
    end
    set_neg_and_zero_flags(res)
  end
end
