module THUMB
  macro thumb_load_store_halfword
    ->(gba : GBA, instr : Word) {
    load = bit?(instr, 11)
    offset = bits(instr, 6..10)
    rb = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    address = gba.cpu.r[rb] + (offset << 1)
    if load
      gba.cpu.set_reg(rd, gba.bus.read_half_rotate(address))
    else
      gba.bus[address] = gba.cpu.r[rd].to_u16!
    end
  }
  end
end
