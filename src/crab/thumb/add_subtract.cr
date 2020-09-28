module THUMB
  def thumb_add_subtract(instr : Word) : Nil
    imm_flag = bit?(instr, 10)
    sub = bit?(instr, 9)
    imm = bits(instr, 6..8)
    rs = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    operand = if imm_flag
                imm
              else
                @r[imm]
              end
    if sub
      @r[rd] = @r[rs] &- operand
    else
      @r[rd] = @r[rs] &+ operand
    end
    # todo handle carry flag on all ops
    @cpsr.zero = @r[rd] == 0
    @cpsr.negative = bit?(@r[rd], 31)
  end
end
