module ARM
  def arm_branch_exchange(instr : Word) : Nil
    rn = bits(instr, 0..3)
    @cpsr.thumb = bit?(@r[rn], 0) 
    set_reg(15, @r[rn])
  end
end
