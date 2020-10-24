module ARM
  def arm_halfword_data_transfer_register(instr : Word) : Nil
    pre_index = bit?(instr, 24)
    add = bit?(instr, 23)
    write_back = bit?(instr, 21)
    load = bit?(instr, 20)
    rn = bits(instr, 16..19)
    rd = bits(instr, 12..15)
    sh = bits(instr, 5..6)
    rm = bits(instr, 0..3)

    address = @r[rn]
    offset = @r[rm]

    if pre_index
      if add
        address &+= offset
      else
        address &-= offset
      end
    end

    case sh
    when 0b00 # swp, no docs on this?
    when 0b01 # ldrh/strh
      if load
        set_reg(rd, @gba.bus.read_half address)
      else
        @gba.bus[address] = 0xFFFF_u16 & @r[rd]
      end
    when 0b10 # ldrsb
      set_reg(rd, @gba.bus[address].to_i8!.to_u32)
    when 0b11 # ldrsh
      set_reg(rd, @gba.bus.read_half(address).to_i16!.to_u32)
    else raise "Invalid halfword data transfer imm op: #{sh}"
    end

    if !pre_index
      if add
        set_reg(rn, @r[rn] &+ offset)
      else
        set_reg(rn, @r[rn] &- offset)
      end
    elsif write_back
      set_reg(rn, address)
    end
  end
end
