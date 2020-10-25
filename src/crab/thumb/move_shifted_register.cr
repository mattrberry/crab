module THUMB
  def thumb_move_shifted_register(instr : Word) : Nil
    op = bits(instr, 11..12)
    offset = bits(instr, 6..10)
    rs = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    case op
    when 0b00 then set_reg(rd, lsl(@r[rs], offset, true))
    when 0b01 then set_reg(rd, lsr(@r[rs], offset, true, true))
    when 0b10 then set_reg(rd, asr(@r[rs], offset, true, true))
    else           raise "Invalid shifted register op: #{op}"
    end
    @cpsr.zero = @r[rd] == 0
    @cpsr.negative = bit?(@r[rd], 31)
  end
end
