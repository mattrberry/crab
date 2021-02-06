module THUMB
  macro thumb_multiple_load_store
    ->(gba : GBA, instr : Word) {
    load = bit?(instr, 11)
    rb = bits(instr, 8..10)
    list = bits(instr, 0..7)
    address = gba.cpu.r[rb]
    unless list == 0
      if load # ldmia
        8.times do |idx|
          if bit?(list, idx)
            gba.cpu.set_reg(idx, gba.bus.read_word(address))
            address &+= 4
          end
        end
      else # stmia
        base_addr = nil
        8.times do |idx|
          if bit?(list, idx)
            gba.bus[address] = gba.cpu.r[idx]
            base_addr = address if rb == idx
            address &+= 4
          end
        end
        gba.bus[base_addr] = address if base_addr && first_set_bit(list) != rb # rb is written after first store
      end
      gba.cpu.set_reg(rb, address)
    else # https://github.com/jsmolka/gba-suite/blob/0e32e15c6241e6dc20851563ba88f4656ac50936/thumb/memory.asm#L459
      if load
        gba.cpu.set_reg(15, gba.bus.read_word(address))
      else
        gba.bus[address] = gba.cpu.r[15] &+ 2
      end
      gba.cpu.set_reg(rb, address &+ 0x40)
    end
  }
  end
end
