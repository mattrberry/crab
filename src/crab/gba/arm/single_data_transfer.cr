module GBA
  module ARM
    def arm_single_data_transfer(instr : UInt32) : Nil
      imm_flag = bit?(instr, 25)
      pre_addressing = bit?(instr, 24)
      add_offset = bit?(instr, 23)
      byte_quantity = bit?(instr, 22)
      write_back = bit?(instr, 21)
      load = bit?(instr, 20)
      rn = bits(instr, 16..19)
      rd = bits(instr, 12..15)

      barrel_shifter_carry_out = false # unused, doesn't matter
      offset = if imm_flag             # Operand 2 is a register (opposite of data processing for some reason)
                 rotate_register bits(instr, 0..11), pointerof(barrel_shifter_carry_out), allow_register_shifts: false
               else # Operand 2 is an immediate offset
                 bits(instr, 0..11)
               end

      address = @r[rn]

      if pre_addressing
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
        # When R15 is the source register (Rd) of a register store (STR) instruction, the stored
        # value will be address of the instruction plus 12.
        @gba.bus[address] &+= 4 if rd == 15
      end

      unless pre_addressing
        if add_offset
          address &+= offset
        else
          address &-= offset
        end
      end
      # In the case of post-addressed addressing, the write back bit is redundant and is always set to
      # zero, since the old base value can be retained by setting the offset to zero. Therefore
      # post-addressed data transfers always write back the modified base.
      set_reg(rn, address) if (write_back || !pre_addressing) && (rd != rn || !load)

      step_arm unless load && rd == 15
    end
  end
end
