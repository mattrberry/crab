module ARM
  def arm_branch_exchange(instr : Word) : Nil
    rn = bits(instr, 0..3)
    if bit?(@r[rn], 0)
      @cpsr.thumb = true
      set_reg(15, @r[rn])
    else
      set_reg(15, @r[rn])
    end
  end
end
