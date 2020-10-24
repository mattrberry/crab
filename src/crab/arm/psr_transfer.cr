module ARM
  def arm_psr_transfer(instr : Word) : Nil
    spsr = bit?(instr, 22)
    msr = bit?(instr, 21)
    if msr
      all = bit?(instr, 16)
      if CPU::Mode.from_value(@cpsr.mode) == CPU::Mode::USR || !all
        mask = 0x0FFFFFFF_u32
      else
        mask = 0x00000000_u32
      end
      imm_flag = bit?(instr, 25)
      if imm_flag
        value = immediate_offset bits(instr, 0..11), set_conditions: false
      else
        rm = bits(instr, 0..3)
        value = @r[rm]
      end
      if spsr
        @spsr.value = (@spsr.value & mask) | (value & ~mask)
      else
        thumb = @cpsr.thumb
        switch_mode CPU::Mode.from_value value & 0x1F if all
        @cpsr.value = (@cpsr.value & mask) | (value & ~mask)
        @cpsr.thumb = thumb
      end
    else
      rd = bits(instr, 12..15)
      if spsr
        set_reg(rd, @spsr.value)
      else
        set_reg(rd, @cpsr.value)
      end
    end
  end
end
