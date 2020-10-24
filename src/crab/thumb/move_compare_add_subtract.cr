module THUMB
  def thumb_move_compare_add_subtract(instr : Word) : Nil
    op = bits(instr, 11..12)
    rd = bits(instr, 8..10)
    offset = bits(instr, 0..7)
    # todo handle carry flag on all ops
    case op
    when 0b00 then res = set_reg(rd, offset)
    when 0b01 then res = sub(@r[rd], offset, true)
    when 0b10 then res = set_reg(rd, add(@r[rd], offset, true))
    when 0b11 then res = set_reg(rd, sub(@r[rd], offset, true))
    else           raise "Invalid move/compare/add/subtract op: #{op}"
    end
    @cpsr.zero = res == 0
    @cpsr.negative = bit?(res, 31)
  end
end
