# The `private defs` here are effectively meaningless since I only run ARM
# functions from the CPU where I include it, but I'm just using it as an
# indicator that the functions should not be called directly outside of the
# module.

module ARM
  def arm_execute(instr : Word) : Nil
    if check_cond bits(instr, 28..31)
      hash = hash_instr instr
      lut[hash].call instr
    else
      log "Skipping instruction, cond: #{hex_str instr >> 28}"
    end
  end

  private def hash_instr(instr : Word) : Word
    (instr >> 16 & 0x0FF0) | (instr >> 4 & 0xF)
  end

  def fill_lut : Slice(Proc(Word, Nil))
    lut = Slice(Proc(Word, Nil)).new 4096, ->arm_unimplemented(Word)
    4096.times do |idx|
      if idx & 0b111100000000 == 0b111100000000
        # software interrupt
      elsif idx & 0b111100000001 == 0b111000000001
        # coprocessor register transfer
      elsif idx & 0b111100000001 == 0b111000000001
        # coprocessor data operation
      elsif idx & 0b111000000000 == 0b110000000000
        # coprocessor data transfer
      elsif idx & 0b111000000000 == 0b101000000000
        lut[idx] = ->arm_branch(Word)
      elsif idx & 0b111000000000 == 0b100000000000
        lut[idx] = ->arm_block_data_transfer(Word)
      elsif idx & 0b111000000001 == 0b011000000001
        # undefined
      elsif idx & 0b110000000000 == 0b010000000000
        lut[idx] = ->arm_single_data_transfer(Word)
      elsif idx & 0b111111111111 == 0b000100100001
        lut[idx] = ->arm_branch_exchange(Word)
      elsif idx & 0b111110111111 == 0b000100001001
        # single data swap
      elsif idx & 0b111110001111 == 0b000010001001
        lut[idx] = ->arm_multiply_long(Word)
      elsif idx & 0b111111001111 == 0b000000001001
        lut[idx] = ->arm_multiply(Word)
      elsif idx & 0b111001001001 == 0b000001001001
        lut[idx] = ->arm_halfword_data_transfer_immediate(Word)
      elsif idx & 0b111001001001 == 0b000000001001
        # halfword data transfer register offset
      elsif idx & 0b110110010000 == 0b000100000000
        lut[idx] = ->arm_psr_transfer(Word)
      elsif idx & 0b110000000000 == 0b000000000000
        lut[idx] = ->arm_data_processing(Word)
      else
        lut[idx] = ->arm_unused(Word)
      end
    end
    lut
  end

  def arm_unimplemented(instr : Word) : Nil
    puts "Unimplemented instruction: #{hex_str instr}"
    exit 1
  end

  def arm_unused(instr : Word) : Nil
    puts "Unused instruction: #{hex_str instr}"
  end

  def rotate_register(instr : Word, set_conditions : Bool, allow_register_shifts = true) : Word
    reg = bits(instr, 0..3)
    shift_type = bits(instr, 5..6)
    shift_amount = if allow_register_shifts && bit?(instr, 4)
                     shift_register = bits(instr, 8..11)
                     # todo weird logic if bottom byte of reg > 31
                     @r[shift_register] & 0xFF
                   else
                     bits(instr, 7..11)
                   end
    case shift_type
    when 0b00 then lsl(@r[reg], shift_amount, set_conditions)
    when 0b01 then lsr(@r[reg], shift_amount, set_conditions)
    when 0b10 then asr(@r[reg], shift_amount, set_conditions)
    when 0b11 then ror(@r[reg], shift_amount, set_conditions)
    else           raise "Impossible shift type: #{hex_str shift_type}"
    end
  end

  def immediate_offset(instr : Word) : Word
    rotate = bits(instr, 8..11)
    imm = bits(instr, 0..7)
    ror(imm, 2 * rotate, false)
  end
end
