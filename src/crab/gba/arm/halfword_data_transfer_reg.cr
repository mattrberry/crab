module GBA
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
        abort "HalfwordDataTransferReg swp #{hex_str instr}"
      when 0b01 # ldrh/strh
        if load
          set_reg(rd, @gba.bus.read_half_rotate address)
        else
          @gba.bus[address] = 0xFFFF_u16 & @r[rd]
          # When R15 is the source register (Rd) of a register store (STR) instruction, the stored
          # value will be address of the instruction plus 12.
          @gba.bus[address] &+= 4 if rd == 15
        end
      when 0b10 # ldrsb
        set_reg(rd, @gba.bus[address].to_i8!.to_u32!)
      when 0b11 # ldrsh
        set_reg(rd, @gba.bus.read_half_signed(address))
      else raise "Invalid halfword data transfer imm op: #{sh}"
      end

      unless pre_index
        if add
          address &+= offset
        else
          address &-= offset
        end
      end
      # In the case of post-indexed addressing, the write back bit is redundant and is always set to
      # zero, since the old base value can be retained by setting the offset to zero. Therefore
      # post-indexed data transfers always write back the modified base.
      set_reg(rn, address) if (write_back || !pre_index) && (rd != rn || !load)

      step_arm unless load && rd == 15
    end
  end
end
