module GBA
  module THUMB
    def thumb_execute(instr : UInt32) : Nil
      thumb_lut[instr >> 8].call instr
    end

    def fill_thumb_lut
      Slice(Proc(UInt32, Nil)).new(256) do |idx|
        case
        when idx & 0b11110000 == 0b11110000 then ->thumb_long_branch_link(UInt32)
        when idx & 0b11111000 == 0b11100000 then ->thumb_unconditional_branch(UInt32)
        when idx & 0b11111111 == 0b11011111 then ->thumb_software_interrupt(UInt32)
        when idx & 0b11110000 == 0b11010000 then ->thumb_conditional_branch(UInt32)
        when idx & 0b11110000 == 0b11000000 then ->thumb_multiple_load_store(UInt32)
        when idx & 0b11110110 == 0b10110100 then ->thumb_push_pop_registers(UInt32)
        when idx & 0b11111111 == 0b10110000 then ->thumb_add_offset_to_stack_pointer(UInt32)
        when idx & 0b11110000 == 0b10100000 then ->thumb_load_address(UInt32)
        when idx & 0b11110000 == 0b10010000 then ->thumb_sp_relative_load_store(UInt32)
        when idx & 0b11110000 == 0b10000000 then ->thumb_load_store_halfword(UInt32)
        when idx & 0b11100000 == 0b01100000 then ->thumb_load_store_immediate_offset(UInt32)
        when idx & 0b11110010 == 0b01010010 then ->thumb_load_store_sign_extended(UInt32)
        when idx & 0b11110010 == 0b01010000 then ->thumb_load_store_register_offset(UInt32)
        when idx & 0b11111000 == 0b01001000 then ->thumb_pc_relative_load(UInt32)
        when idx & 0b11111100 == 0b01000100 then ->thumb_high_reg_branch_exchange(UInt32)
        when idx & 0b11111100 == 0b01000000 then ->thumb_alu_operations(UInt32)
        when idx & 0b11100000 == 0b00100000 then ->thumb_move_compare_add_subtract(UInt32)
        when idx & 0b11111000 == 0b00011000 then ->thumb_add_subtract(UInt32)
        when idx & 0b11100000 == 0b00000000 then ->thumb_move_shifted_register(UInt32)
        else                                     ->thumb_unimplemented(UInt32)
        end
      end
    end

    def thumb_unimplemented(instr : UInt32) : Nil
      # "if true" is a hack until https://github.com/crystal-lang/crystal/issues/12758 is patched
      abort "Unimplemented instruction: #{hex_str instr.to_u16}" if true
    end
  end
end
