module ARM
  def arm_single_data_transfer(instr : Word) : Nil
    imm_flag = bit?(instr, 25)
    pre_indexing = bit?(instr, 24)
    add_offset = bit?(instr, 23)
    byte_quantity = bit?(instr, 22)
    write_back = bit?(instr, 21)
    load = bit?(instr, 20)
    rn = bits(instr, 16..19)
    rd = bits(instr, 12..15)
    barrel_shifter_carry_out = false # unused, doesn't matter

    offset = if imm_flag # Operand 2 is a register (opposite of data processing for some reason)
               rotate_register bits(instr, 0..11), pointerof(barrel_shifter_carry_out), allow_register_shifts: false
             else # Operand 2 is an immediate offset
               bits(instr, 0..11)
             end

    address = @r[rn]

    if pre_indexing
      if add_offset
        address &+= offset
      else
        address &-= offset
      end
    end

    if load
      if byte_quantity
        set_reg(rd, @gba.bus[address].to_u32)
      else
        set_reg(rd, @gba.bus.read_word_rotate address)
      end
    else
      if byte_quantity
        @gba.bus[address] = @r[rd].to_u8!
      else
        @gba.bus[address] = @r[rd]
      end
    end

    unless pre_indexing
      if add_offset
        address &+= offset
      else
        address &-= offset
      end
    end
    # In the case of post-indexed addressing, the write back bit is redundant and is always set to
    # zero, since the old base value can be retained by setting the offset to zero. Therefore
    # post-indexed data transfers always write back the modified base.
    set_reg(rn, address) if (write_back || !pre_indexing) && rd != rn
  end
end
