module ARM
  def arm_block_data_transfer(instr : Word) : Nil
    pre_index = bit?(instr, 24)
    add = bit?(instr, 23)
    s_bit = bit?(instr, 22)
    write_back = bit?(instr, 21)
    load = bit?(instr, 20)
    rn = bits(instr, 16..19)
    list = bits(instr, 0..15)

    if s_bit
      abort "todo: handle cases with r15 in list" if bit?(list, 15)
      mode = @cpsr.mode
      switch_mode CPU::Mode::USR
    end

    address = @r[rn]

    step = add ? 4 : -4
    idxs = add ? 16.times : 15.downto(0)

    if load
      idxs.each do |idx|
        if bit?(list, idx)
          address &+= step if pre_index
          set_reg(idx, @gba.bus.read_word(address))
          address &+= step unless pre_index
        end
      end
    else
      idxs.each do |idx|
        if bit?(list, idx)
          address &+= step if pre_index
          @gba.bus[address] = @r[idx]
          address &+= step unless pre_index
        end
      end
    end

    if s_bit
      switch_mode CPU::Mode.from_value mode.not_nil!
    end

    # todo stm where rn is 2nd or further in list loads the original address
    set_reg(rn, address) if write_back && !(load && bit?(list, rn))
  end
end
