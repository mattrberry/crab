module ARM
  def arm_block_data_transfer(instr : Word) : Nil
    pre_index = bit?(instr, 24)
    add = bit?(instr, 23)
    s_bit = bit?(instr, 22) # todo respect this bit
    write_back = bit?(instr, 21)
    load = bit?(instr, 20)
    rn = bits(instr, 16..19)
    list = bits(instr, 0..15)

    address = @r[rn]

    if load
      16.times do |idx|
        if bit?(list, idx)
          address &+= add ? 4 : -4 if pre_index
          set_reg(idx, @gba.bus.read_word(address))
          address &+= add ? 4 : -4 unless pre_index
        end
      end
    else
      15.downto(0).each do |idx|
        if bit?(list, idx)
          address &+= add ? 4 : -4 if pre_index
          @gba.bus[address] = @r[idx]
          address &+= add ? 4 : -4 unless pre_index
        end
      end
    end

    set_reg(rn, address) if write_back
  end
end
