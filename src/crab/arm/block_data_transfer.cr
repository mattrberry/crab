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
          @r[idx] = @gba.bus.read_word(address)
          address &+= add ? 4 : -4 unless pre_index
        end
      end
    else
      16.times do |idx|
        if bit?(list, idx)
          address &+= add ? 4 : -4 if pre_index
          @gba.bus[address] = @r[idx]
          address &+= add ? 4 : -4 unless pre_index
        end
      end
    end

    @r[rn] = address if write_back
    # todo reset pipeline if r15 is written (this needs to be done in all other instrs that write to r15 as well)
  end
end
