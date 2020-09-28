module THUMB
  def thumb_execute(instr : Word) : Nil
    thumb_lut[instr >> 8].call instr
  end

  def fill_thumb_lut
    lut = Slice(Proc(Word, Nil)).new 256, ->thumb_unimplemented(Word)
    256.times do |idx|
      if idx & 0b11110000 == 0b11110000
        # long branch with link
      elsif idx & 0b11111000 == 0b11100000
        # unconditional branch
      elsif idx & 0b11111111 == 0b11011111
        # software interrupt
      elsif idx & 0b11110000 == 0b11010000
        lut[idx] = ->thumb_conditional_branch(Word)
      elsif idx & 0b11110000 == 0b11000000
        # multiple load/store
      elsif idx & 0b11110110 == 0b10110100
        # push/pop registers
      elsif idx & 0b11111111 == 0b10110000
        # add offset to stack pointer
      elsif idx & 0b11110000 == 0b10100000
        # load address
      elsif idx & 0b11110000 == 0b10010000
        # sp-relative load/store
      elsif idx & 0b11110000 == 0b10000000
        # load/store halfword
      elsif idx & 0b11100000 == 0b01100000
        # load/store with immediate offset
      elsif idx & 0b11110010 == 0b01010010
        # load/store sign-extended byte/halfword
      elsif idx & 0b11110010 == 0b01010000
        # load/store with register offset
      elsif idx & 0b11111000 == 0b01001000
        lut[idx] = ->thumb_pc_relative_load(Word)
      elsif idx & 0b11111100 == 0b01000100
        # hi register operations / branch exchange
      elsif idx & 0b11111100 == 0b01000000
        # alu operations
      elsif idx & 0b11100000 == 0b00100000
        lut[idx] = ->thumb_move_compare_add_subtract(Word)
      elsif idx & 0b11111100 == 0b00011000
        # add/subtract
      elsif idx & 0b11100000 == 0b00000000
        lut[idx] = ->thumb_move_shifted_register(Word)
      end
    end
    lut
  end

  def thumb_unimplemented(instr : Word) : Nil
    puts "Unimplemented instruction: #{hex_str instr.to_u16}"
    exit 1
  end
end
