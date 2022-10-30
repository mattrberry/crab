module GBA
  module THUMB
    def thumb_execute(instr : UInt32) : Nil
      thumb_lut[instr >> 8].call instr
    end

    def fill_thumb_lut
      lut = Slice(Proc(UInt32, Nil)).new 256, ->thumb_unimplemented(UInt32)
      256.times do |idx|
        if idx & 0b11110000 == 0b11110000
          lut[idx] = ->thumb_long_branch_link(UInt32)
        elsif idx & 0b11111000 == 0b11100000
          lut[idx] = ->thumb_unconditional_branch(UInt32)
        elsif idx & 0b11111111 == 0b11011111
          lut[idx] = ->thumb_software_interrupt(UInt32)
        elsif idx & 0b11110000 == 0b11010000
          lut[idx] = ->thumb_conditional_branch(UInt32)
        elsif idx & 0b11110000 == 0b11000000
          lut[idx] = ->thumb_multiple_load_store(UInt32)
        elsif idx & 0b11110110 == 0b10110100
          lut[idx] = ->thumb_push_pop_registers(UInt32)
        elsif idx & 0b11111111 == 0b10110000
          lut[idx] = ->thumb_add_offset_to_stack_pointer(UInt32)
        elsif idx & 0b11110000 == 0b10100000
          lut[idx] = ->thumb_load_address(UInt32)
        elsif idx & 0b11110000 == 0b10010000
          lut[idx] = ->thumb_sp_relative_load_store(UInt32)
        elsif idx & 0b11110000 == 0b10000000
          lut[idx] = ->thumb_load_store_UInt16(UInt32)
        elsif idx & 0b11100000 == 0b01100000
          lut[idx] = ->thumb_load_store_immediate_offset(UInt32)
        elsif idx & 0b11110010 == 0b01010010
          lut[idx] = ->thumb_load_store_sign_extended(UInt32)
        elsif idx & 0b11110010 == 0b01010000
          lut[idx] = ->thumb_load_store_register_offset(UInt32)
        elsif idx & 0b11111000 == 0b01001000
          lut[idx] = ->thumb_pc_relative_load(UInt32)
        elsif idx & 0b11111100 == 0b01000100
          lut[idx] = ->thumb_high_reg_branch_exchange(UInt32)
        elsif idx & 0b11111100 == 0b01000000
          lut[idx] = ->thumb_alu_operations(UInt32)
        elsif idx & 0b11100000 == 0b00100000
          lut[idx] = ->thumb_move_compare_add_subtract(UInt32)
        elsif idx & 0b11111000 == 0b00011000
          lut[idx] = ->thumb_add_subtract(UInt32)
        elsif idx & 0b11100000 == 0b00000000
          lut[idx] = ->thumb_move_shifted_register(UInt32)
        end
      end
      lut
    end

    def thumb_unimplemented(instr : UInt32) : Nil
      abort "Unimplemented instruction: #{hex_str instr.to_u16}"
    end
  end
end
