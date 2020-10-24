module THUMB
  def thumb_load_address(instr : Word) : Nil
    source = bit?(instr, 11)
    rd = bits(instr, 8..10)
    word = bits(instr, 0..8)
    imm = word << 2
    set_reg(rd, (source ? @r[13] : @r[15]) &+ imm)
  end
end
