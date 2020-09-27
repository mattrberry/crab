module ARM
  def arm_branch_exchange(instr : Word) : Nil
    rn = bits(instr, 0..3)
    if bit?(@r[rn], 0)
      @cpsr.thumb = true
      @r[15] = @r[rn] & ~1
    else
      @r[15] = @r[rn] & ~3
    end
    clear_pipeline
  end
end
