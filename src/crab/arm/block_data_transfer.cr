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

    unless list == 0
      if load
        idxs.each do |idx|
          if bit?(list, idx)
            address &+= step if pre_index
            set_reg(idx, @gba.bus.read_word(address))
            address &+= step unless pre_index
          end
        end
      else
        base_addr = nil
        idxs.each do |idx|
          if bit?(list, idx)
            address &+= step if pre_index
            @gba.bus[address] = @r[idx]
            @gba.bus[address] &+= 4 if idx == 15
            base_addr = address if rn == idx
            address &+= step unless pre_index
          end
        end
        @gba.bus[base_addr] = address if base_addr && first_set_bit(list) != rn # rn is written after first store
      end
    else                             # https://github.com/jsmolka/gba-suite/blob/master/arm/block_transfer.asm#L214
      offset = case {add, pre_index} # todo stop hard coding this, but it'll do for now...
               when {true, true}   then 0x4
               when {true, false}  then 0x0
               when {false, true}  then -0x40
               when {false, false} then -0x3C
               else                     abort "Impossible ldm/stm empty list case"
               end
      if load
        set_reg(15, @gba.bus.read_word(address &+ offset))
      else
        @gba.bus[address &+ offset] = @r[15] &+ 4
      end
      address &+= 0x10 * step
    end

    if s_bit
      switch_mode CPU::Mode.from_value mode.not_nil!
    end

    set_reg(rn, address) if write_back && !(load && bit?(list, rn))
  end
end
