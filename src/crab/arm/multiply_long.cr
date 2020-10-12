module ARM
  def arm_multiply_long(instr : Word) : Nil
    signed = bit?(instr, 22)
    accumulate = bit?(instr, 21)
    set_conditions = bit?(instr, 20)
    rdhi = bits(instr, 16..19)
    rdlo = bits(instr, 12..15)
    rs = bits(instr, 12..15)
    rm = bits(instr, 0..3)

    res = if signed
            (@r[rm].to_i32!.to_i64 &* @r[rs]).to_u64 # todo make this just bit math...
          else
            (0_u64 | @r[rm]) &* @r[rs]
          end
    res &+= (0_u64 | @r[rdhi]) << 32 | @r[rdlo] if accumulate
    @r[rdhi] = 0_u32 | res >> 32
    @r[rdlo] = 0xFFFFFFFF_u32 & res
    if set_conditions
      @cpsr.zero = res == 0
      @cpsr.negative = bit?(res, 63)
    end
  end
end
