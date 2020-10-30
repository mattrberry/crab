module THUMB
  def thumb_load_address(instr : Word) : Nil
    source = bit?(instr, 11)
    rd = bits(instr, 8..10)
    word = bits(instr, 0..8)
    imm = word << 2
    # Where the PC is used as the source register (SP = 0), bit 1 of the PC is always read as 0.
    set_reg(rd, (source ? @r[13] : @r[15] & ~2) &+ imm)
  end
end
