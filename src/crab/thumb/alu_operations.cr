module THUMB
  macro thumb_alu_operations
    ->(gba : GBA, instr : Word) {
    op = bits(instr, 6..9)
    rs = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    barrel_shifter_carry_out = gba.cpu.cpsr.carry
    case op
    when 0b0000 then res = gba.cpu.set_reg(rd, gba.cpu.r[rd] & gba.cpu.r[rs])
    when 0b0001 then res = gba.cpu.set_reg(rd, gba.cpu.r[rd] ^ gba.cpu.r[rs])
    when 0b0010
      res = gba.cpu.set_reg(rd, gba.cpu.lsl(gba.cpu.r[rd], gba.cpu.r[rs], pointerof(barrel_shifter_carry_out)))
      gba.cpu.cpsr.carry = barrel_shifter_carry_out
    when 0b0011
      res = gba.cpu.set_reg(rd, gba.cpu.lsr(gba.cpu.r[rd], gba.cpu.r[rs], false, pointerof(barrel_shifter_carry_out)))
      gba.cpu.cpsr.carry = barrel_shifter_carry_out
    when 0b0100
      res = gba.cpu.set_reg(rd, gba.cpu.asr(gba.cpu.r[rd], gba.cpu.r[rs], false, pointerof(barrel_shifter_carry_out)))
      gba.cpu.cpsr.carry = barrel_shifter_carry_out
    when 0b0101 then res = gba.cpu.set_reg(rd, gba.cpu.adc(gba.cpu.r[rd], gba.cpu.r[rs], set_conditions: true))
    when 0b0110 then res = gba.cpu.set_reg(rd, gba.cpu.sbc(gba.cpu.r[rd], gba.cpu.r[rs], set_conditions: true))
    when 0b0111
      res = gba.cpu.set_reg(rd, gba.cpu.ror(gba.cpu.r[rd], gba.cpu.r[rs], false, pointerof(barrel_shifter_carry_out)))
      gba.cpu.cpsr.carry = barrel_shifter_carry_out
    when 0b1000 then res = gba.cpu.r[rd] & gba.cpu.r[rs]
    when 0b1001 then res = gba.cpu.set_reg(rd, gba.cpu.sub(0, gba.cpu.r[rs], set_conditions: true))
    when 0b1010 then res = gba.cpu.sub(gba.cpu.r[rd], gba.cpu.r[rs], set_conditions: true)
    when 0b1011 then res = gba.cpu.add(gba.cpu.r[rd], gba.cpu.r[rs], set_conditions: true)
    when 0b1100 then res = gba.cpu.set_reg(rd, gba.cpu.r[rd] | gba.cpu.r[rs])
    when 0b1101 then res = gba.cpu.set_reg(rd, gba.cpu.r[rs] &* gba.cpu.r[rd])
    when 0b1110 then res = gba.cpu.set_reg(rd, gba.cpu.r[rd] & ~gba.cpu.r[rs])
    when 0b1111 then res = gba.cpu.set_reg(rd, ~gba.cpu.r[rs])
    else             raise "Invalid alu op: #{op}"
    end
    gba.cpu.set_neg_and_zero_flags(res)
  }
  end
end
