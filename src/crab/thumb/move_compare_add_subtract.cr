module THUMB
  def thumb_move_compare_add_subtract(instr : Word) : Nil
    op = bits(instr, 11..12)
    rd = bits(instr, 8..10)
    offset = bits(instr, 0..7)
    case op
    when 0b00
      set_reg(rd, offset)
      set_neg_and_zero_flags(@r[rd])
    when 0b01 then sub(@r[rd], offset, true)
    when 0b10 then set_reg(rd, add(@r[rd], offset, true))
    when 0b11 then set_reg(rd, sub(@r[rd], offset, true))
    else           raise "Invalid move/compare/add/subtract op: #{op}"
    end
  end
end
