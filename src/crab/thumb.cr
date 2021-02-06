module THUMB
  def thumb_execute(gba : GBA, instr : Word) : Nil
    THUMB_LUT[instr >> 8].call gba, instr
  end

  macro meme
    THUMB_LUT = Array(Proc(GBA, Word, Nil)).new 256, thumb_unimplemented
    {% for idx in (0...256) %}
      {% if idx & 0b11110000 == 0b11110000 %}
        THUMB_LUT[{{idx}}] = thumb_long_branch_link
      {% elsif idx & 0b11111000 == 0b11100000 %}
        THUMB_LUT[{{idx}}] = thumb_unconditional_branch
      {% elsif idx & 0b11111111 == 0b11011111 %}
        THUMB_LUT[{{idx}}] = thumb_software_interrupt
      {% elsif idx & 0b11110000 == 0b11010000 %}
        THUMB_LUT[{{idx}}] = thumb_conditional_branch
      {% elsif idx & 0b11110000 == 0b11000000 %}
        THUMB_LUT[{{idx}}] = thumb_multiple_load_store
      {% elsif idx & 0b11110110 == 0b10110100 %}
        THUMB_LUT[{{idx}}] = thumb_push_pop_registers
      {% elsif idx & 0b11111111 == 0b10110000 %}
        THUMB_LUT[{{idx}}] = thumb_add_offset_to_stack_pointer
      {% elsif idx & 0b11110000 == 0b10100000 %}
        THUMB_LUT[{{idx}}] = thumb_load_address
      {% elsif idx & 0b11110000 == 0b10010000 %}
        THUMB_LUT[{{idx}}] = thumb_sp_relative_load_store
      {% elsif idx & 0b11110000 == 0b10000000 %}
        THUMB_LUT[{{idx}}] = thumb_load_store_halfword
      {% elsif idx & 0b11100000 == 0b01100000 %}
        THUMB_LUT[{{idx}}] = thumb_load_store_immediate_offset
      {% elsif idx & 0b11110010 == 0b01010010 %}
        THUMB_LUT[{{idx}}] = thumb_load_store_sign_extended
      {% elsif idx & 0b11110010 == 0b01010000 %}
        THUMB_LUT[{{idx}}] = thumb_load_store_register_offset
      {% elsif idx & 0b11111000 == 0b01001000 %}
        THUMB_LUT[{{idx}}] = thumb_pc_relative_load
      {% elsif idx & 0b11111100 == 0b01000100 %}
        THUMB_LUT[{{idx}}] = thumb_high_reg_branch_exchange
      {% elsif idx & 0b11111100 == 0b01000000 %}
        THUMB_LUT[{{idx}}] = thumb_alu_operations
      {% elsif idx & 0b11100000 == 0b00100000 %}
        THUMB_LUT[{{idx}}] = thumb_move_compare_add_subtract
      {% elsif idx & 0b11111000 == 0b00011000 %}
        THUMB_LUT[{{idx}}] = thumb_add_subtract
      {% elsif idx & 0b11100000 == 0b00000000 %}
        THUMB_LUT[{{idx}}] = thumb_move_shifted_register
      {% end %}
    {% end %}
  end

  meme

  def fill_thumb_lut
    lut = Slice(Proc(Word, Nil)).new 256, ->thumb_unimplemented(Word)
    256.times do |idx|
      if idx & 0b11110000 == 0b11110000
        lut[idx] = ->thumb_long_branch_link(Word)
      elsif idx & 0b11111000 == 0b11100000
        lut[idx] = ->thumb_unconditional_branch(Word)
      elsif idx & 0b11111111 == 0b11011111
        lut[idx] = ->thumb_software_interrupt(Word)
      elsif idx & 0b11110000 == 0b11010000
        lut[idx] = ->thumb_conditional_branch(Word)
      elsif idx & 0b11110000 == 0b11000000
        lut[idx] = ->thumb_multiple_load_store(Word)
      elsif idx & 0b11110110 == 0b10110100
        lut[idx] = ->thumb_push_pop_registers(Word)
      elsif idx & 0b11111111 == 0b10110000
        lut[idx] = ->thumb_add_offset_to_stack_pointer(Word)
      elsif idx & 0b11110000 == 0b10100000
        lut[idx] = ->thumb_load_address(Word)
      elsif idx & 0b11110000 == 0b10010000
        lut[idx] = ->thumb_sp_relative_load_store(Word)
      elsif idx & 0b11110000 == 0b10000000
        lut[idx] = ->thumb_load_store_halfword(Word)
      elsif idx & 0b11100000 == 0b01100000
        lut[idx] = ->thumb_load_store_immediate_offset(Word)
      elsif idx & 0b11110010 == 0b01010010
        lut[idx] = ->thumb_load_store_sign_extended(Word)
      elsif idx & 0b11110010 == 0b01010000
        lut[idx] = ->thumb_load_store_register_offset(Word)
      elsif idx & 0b11111000 == 0b01001000
        lut[idx] = ->thumb_pc_relative_load(Word)
      elsif idx & 0b11111100 == 0b01000100
        lut[idx] = ->thumb_high_reg_branch_exchange(Word)
      elsif idx & 0b11111100 == 0b01000000
        lut[idx] = ->thumb_alu_operations(Word)
      elsif idx & 0b11100000 == 0b00100000
        lut[idx] = ->thumb_move_compare_add_subtract(Word)
      elsif idx & 0b11111000 == 0b00011000
        lut[idx] = ->thumb_add_subtract(Word)
      elsif idx & 0b11100000 == 0b00000000
        lut[idx] = ->thumb_move_shifted_register(Word)
      end
    end
    lut
  end

  macro thumb_unimplemented
    ->(gba : GBA, instr : Word) {
      puts "Unimplemented instruction: #{hex_str instr.to_u16}"
      exit 1
    }
  end
end
