module ARM
  def arm_multiply(instr : Word) : Nil
    accumulate = bit?(instr, 21)
    set_conditions = bit?(instr, 20)
    rd = bits(instr, 16..19)
    rn = bits(instr, 12..15)
    rs = bits(instr, 8..11)
    rm = bits(instr, 0..3)

    @r[rd] = @r[rm] &* @r[rs]
    @r[rd] &+= @r[rn] if accumulate
    if set_conditions
      @cpsr.zero = @r[rd] == 0
      @cpsr.negative = bit?(@r[rd], 31)
    end
  end
end
