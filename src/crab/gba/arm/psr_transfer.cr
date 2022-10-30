module GBA
  module ARM
    def arm_psr_transfer(instr : UInt32) : Nil
      spsr = bit?(instr, 22)
      mode = CPU::Mode.from_value @cpsr.mode
      has_spsr = mode != CPU::Mode::USR && mode != CPU::Mode::SYS

      if bit?(instr, 21) # MSR
        mask = 0_u32
        mask |= 0xFF000000 if bit?(instr, 19) # f (aka _flg)
        mask |= 0x00FF0000 if bit?(instr, 18) # s
        mask |= 0x0000FF00 if bit?(instr, 17) # x
        mask |= 0x000000FF if bit?(instr, 16) # c (aka _ctl)

        if bit?(instr, 25)                 # immediate
          barrel_shifter_carry_out = false # unused, doesn't matter
          value = immediate_offset bits(instr, 0..11), pointerof(barrel_shifter_carry_out)
        else # register value
          value = @r[bits(instr, 0..3)]
        end

        value &= mask
        if spsr
          if has_spsr
            @spsr.value = (@spsr.value & ~mask) | value
          end
        else
          thumb = @cpsr.thumb
          switch_mode CPU::Mode.from_value value & 0x1F if mask & 0xFF > 0
          @cpsr.value = (@cpsr.value & ~mask) | value
          @cpsr.thumb = thumb
        end
      else # MRS
        rd = bits(instr, 12..15)
        if spsr && has_spsr
          set_reg(rd, @spsr.value)
        else
          set_reg(rd, @cpsr.value)
        end
      end

      step_arm unless !bit?(instr, 21) && bits(instr, 12..15) == 15
    end
  end
end
