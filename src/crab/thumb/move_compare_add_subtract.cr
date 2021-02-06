module THUMB
  macro thumb_move_compare_add_subtract
    ->(gba : GBA, instr : Word) {
    op = bits(instr, 11..12)
    rd = bits(instr, 8..10)
    offset = bits(instr, 0..7)
    case op
    when 0b00
      gba.cpu.set_reg(rd, offset)
      gba.cpu.set_neg_and_zero_flags(gba.cpu.r[rd])
    when 0b01 then gba.cpu.sub(gba.cpu.r[rd], offset, true)
    when 0b10 then gba.cpu.set_reg(rd, gba.cpu.add(gba.cpu.r[rd], offset, true))
    when 0b11 then gba.cpu.set_reg(rd, gba.cpu.sub(gba.cpu.r[rd], offset, true))
    else           raise "Invalid move/compare/gba.cpu.add/gba.cpu.subtract op: #{op}"
    end
  }
  end
end
