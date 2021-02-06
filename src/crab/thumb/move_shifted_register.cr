module THUMB
  macro thumb_move_shifted_register
    ->(gba : GBA, instr : Word) {
    op = bits(instr, 11..12)
    offset = bits(instr, 6..10)
    rs = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    carry_out = gba.cpu.cpsr.carry
    case op
    when 0b00 then gba.cpu.set_reg(rd, gba.cpu.lsl(gba.cpu.r[rs], offset, pointerof(carry_out)))
    when 0b01 then gba.cpu.set_reg(rd, gba.cpu.lsr(gba.cpu.r[rs], offset, true, pointerof(carry_out)))
    when 0b10 then gba.cpu.set_reg(rd, gba.cpu.asr(gba.cpu.r[rs], offset, true, pointerof(carry_out)))
    else           raise "Invalid shifted register op: #{op}"
    end
    gba.cpu.set_neg_and_zero_flags(gba.cpu.r[rd])
    gba.cpu.cpsr.carry = carry_out
  }
  end
end
