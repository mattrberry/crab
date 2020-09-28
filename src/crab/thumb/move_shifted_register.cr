module THUMB
  def thumb_move_shifted_register(instr : Word) : Nil
    # todo carry flags (currently first divergence on armwrestler)
    op = bits(instr, 11..12)
    offset = bits(instr, 6..10)
    rs = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    @r[rd] = case op
             when 0b00 then @r[rs] << offset
             when 0b01 then @r[rs] >> offset
             when 0b10 then @r[rs] // (2 ** offset)
             else           raise "Invalid shifted register op: #{op}"
             end
    @cpsr.zero = @r[rd] == 0
    @cpsr.negative = bit?(@r[rd], 31)
  end
end
