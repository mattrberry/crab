module ARM
  def arm_psr_transfer(instr : Word) : Nil
    # todo respect spsr
    spsr = bit?(instr, 22)
    msr = bit?(instr, 21)
    if msr
      all = bit?(instr, 16)
      if all
        rm = bits(instr, 0..3)
        @cpsr.value = @r[rm]
      else
        imm_flag = bit?(instr, 25)
        value = if imm_flag
                  immediate_offset bits(instr, 0..11)
                else
                  rm = bits(instr, 0..3)
                  @r[rm]
                end
        @cpsr.value = (@cpsr.value & 0x0FFFFFFF) | (value & 0xF0000000)
      end
    else
      rd = bits(instr, 12..15)
      @r[rd] = @cpsr.value
    end
  end
end
