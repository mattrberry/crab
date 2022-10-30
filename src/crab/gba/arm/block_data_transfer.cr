module GBA
  module ARM
    def arm_block_data_transfer(instr : UInt32) : Nil
      pre_address = bit?(instr, 24)
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
      bits_set = count_set_bits(list)
      if bits_set == 0 # odd behavior on empty list, tested in gba-suite
        bits_set = 16
        list = 0x8000
      end
      final_addr = address + bits_set * (add ? 4 : -4)
      if add
        address += 4 if pre_address
      else
        address = final_addr
        address += 4 unless pre_address
      end
      first_transfer = false
      16.times do |idx| # always transfered to/from incrementing addresses
        if bit?(list, idx)
          if load
            set_reg(idx, @gba.bus.read_word(address))
          else
            @gba.bus[address] = @r[idx]
            @gba.bus[address] &+= 4 if idx == 15 # pc reads 12 ahead instead of 8
          end
          address += 4 # can always do these post since the address was accounted for up front
          set_reg(rn, final_addr) if write_back && !first_transfer && !(load && bit?(list, rn))
          first_transfer = true # writeback happens on second cycle of the instruction
        end
      end

      if s_bit
        switch_mode CPU::Mode.from_value mode.not_nil!
      end

      step_arm unless load && bit?(list, 15)
    end
  end
end
