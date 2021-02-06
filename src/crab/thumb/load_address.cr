module THUMB
  macro thumb_load_address
    ->(gba : GBA, instr : Word) {
    source = bit?(instr, 11)
    rd = bits(instr, 8..10)
    word = bits(instr, 0..7)
    imm = word << 2
    # Where the PC is used as the source register (SP = 0), bit 1 of the PC is always read as 0.
    gba.cpu.set_reg(rd, (source ? gba.cpu.r[13] : gba.cpu.r[15] & ~2) &+ imm)
  }
  end
end
