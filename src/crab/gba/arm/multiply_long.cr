module GBA
  module ARM
    def arm_multiply_long(instr : UInt32) : Nil
      signed = bit?(instr, 22)
      accumulate = bit?(instr, 21)
      set_conditions = bit?(instr, 20)
      rdhi = bits(instr, 16..19)
      rdlo = bits(instr, 12..15)
      rs = bits(instr, 8..11)
      rm = bits(instr, 0..3)

      res = if signed
              @r[rm].to_i32!.to_i64 &* @r[rs].to_i32!
            else
              @r[rm].to_u64 &* @r[rs]
            end
      res &+= @r[rdhi].to_u64 << 32 | @r[rdlo] if accumulate

      set_reg(rdhi, (res >> 32).to_u32!)
      set_reg(rdlo, res.to_u32!)
      if set_conditions
        @cpsr.negative = bit?(@r[rdhi], 31)
        @cpsr.zero = res == 0
      end

      step_arm unless rdhi == 15 || rdlo == 15
    end
  end
end
