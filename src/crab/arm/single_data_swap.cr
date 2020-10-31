module ARM
  def arm_single_data_swap(instr : Word) : Nil
    byte_quantity = bit?(instr, 22)
    rn = bits(instr, 16..19)
    rd = bits(instr, 12..15)
    rm = bits(instr, 0..3)
    if byte_quantity
      tmp = @gba.bus[@r[rn]]
      @gba.bus[@r[rn]] = @r[rm].to_u8!
      set_reg(rd, tmp.to_u32)
    else
      tmp = @gba.bus.read_word_rotate @r[rn]
      @gba.bus[@r[rn]] = @r[rm]
      set_reg(rd, tmp)
    end
  end
end
