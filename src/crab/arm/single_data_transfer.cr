module ARM
  def arm_single_data_transfer(instr : Word) : Nil
    # todo revisit this whole instruction. ldr/str have some weird edge cases iirc..
    imm_flag = bit?(instr, 25)
    pre_indexing = bit?(instr, 24)
    add_offset = bit?(instr, 23)
    byte_quantity = bit?(instr, 22)
    write_back = bit?(instr, 21)
    load = bit?(instr, 20)
    rn = bits(instr, 16..19)
    rd = bits(instr, 12..15)
    offset = if imm_flag # Operand 2 is a register (opposite of data processing for some reason)
               rotate_register bits(instr, 0..11), set_conditions: false, allow_register_shifts: false
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
      @r[rd] = @gba.bus.read_word address
    else
      @gba.bus[address] = @r[rd]
    end

    if !pre_indexing
      if add_offset
        @r[rn] &+= offset
      else
        @r[rn] &-= offset
      end
    elsif write_back
      @r[rn] = address
    end
  end
end
