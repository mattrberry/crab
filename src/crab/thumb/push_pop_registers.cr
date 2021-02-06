module THUMB
  macro thumb_push_pop_registers
    ->(gba : GBA, instr : Word) {
    pop = bit?(instr, 11)
    pclr = bit?(instr, 8)
    list = bits(instr, 0..7)
    address = gba.cpu.r[13]
    if pop
      8.times do |idx|
        if bit?(list, idx)
          gba.cpu.set_reg(idx, gba.bus.read_word(address))
          address &+= 4
        end
      end
      if pclr
        gba.cpu.set_reg(15, gba.bus.read_word(address))
        address &+= 4
      end
    else
      if pclr
        address &-= 4
        gba.bus[address] = gba.cpu.r[14]
      end
      7.downto(0).each do |idx|
        if bit?(list, idx)
          address &-= 4
          gba.bus[address] = gba.cpu.r[idx]
        end
      end
    end
    gba.cpu.set_reg(13, address)
  }
  end
end
