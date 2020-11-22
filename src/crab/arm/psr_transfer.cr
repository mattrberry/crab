module ARM
  def arm_psr_transfer(instr : Word) : Nil
    spsr = bit?(instr, 22)
    if bit?(instr, 21) # MSR
      mask = 0_u32 # described in gbatek, not in arm manual https://problemkaputt.de/gbatek.htm#armopcodespsrtransfermrsmsr
      mask |= 0xFF000000 if bit?(instr, 19) # f (aka _flg)
      mask |= 0x00FF0000 if bit?(instr, 18) # s
      mask |= 0x0000FF00 if bit?(instr, 17) # x
      mask |= 0x000000FF if bit?(instr, 16) # c (aka _ctl)
      if bit?(instr, 25) # immediate
        barrel_shifter_carry_out = false # unused, doesn't matter
        value = immediate_offset bits(instr, 0..11), pointerof(barrel_shifter_carry_out)
      else # register value
        value = @r[bits(instr, 0..3)]
      end
      value &= mask
      if spsr
        @spsr.value = (@spsr.value & ~mask) | value
      else
        thumb = @cpsr.thumb
        switch_mode CPU::Mode.from_value value & 0x1F if mask & 0xFF > 0
        @cpsr.value = (@cpsr.value & ~mask) | value
        @cpsr.thumb = thumb
      end
    else # MRS
      rd = bits(instr, 12..15)
      if spsr
        set_reg(rd, @spsr.value)
      else
        set_reg(rd, @cpsr.value)
      end
    end
  end
end
