module THUMB
  macro thumb_sp_relative_load_store
    ->(gba : GBA, instr : Word) {
    load = bit?(instr, 11)
    rd = bits(instr, 8..10)
    word = bits(instr, 0..7)
    address = gba.cpu.r[13] &+ (word << 2)
    if load
      gba.cpu.set_reg(rd, gba.bus.read_word_rotate(address))
    else
      gba.bus[address] = gba.cpu.r[rd]
    end
  }
  end
end
