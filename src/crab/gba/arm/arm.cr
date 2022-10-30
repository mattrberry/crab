module GBA
  # The `private defs` here are effectively meaningless since I only run ARM
  # functions from the CPU where I include it, but I'm just using it as an
  # indicator that the functions should not be called directly outside of the
  # module.

  module ARM
    def arm_execute(instr : UInt32) : Nil
      if check_cond bits(instr, 28..31)
        hash = hash_instr instr
        lut[hash].call instr
      else
        log "Skipping instruction, cond: #{hex_str instr >> 28}"
        step_arm
      end
    end

    private def hash_instr(instr : UInt32) : UInt32
      (instr >> 16 & 0x0FF0) | (instr >> 4 & 0xF)
    end

    def fill_lut : Slice(Proc(UInt32, Nil))
      lut = Slice(Proc(UInt32, Nil)).new 4096, ->arm_unimplemented(UInt32)
      4096.times do |idx|
        if idx & 0b111100000000 == 0b111100000000
          lut[idx] = ->arm_software_interrupt(UInt32)
        elsif idx & 0b111100000001 == 0b111000000001
          # coprocessor register transfer
        elsif idx & 0b111100000001 == 0b111000000001
          # coprocessor data operation
        elsif idx & 0b111000000000 == 0b110000000000
          # coprocessor data transfer
        elsif idx & 0b111000000000 == 0b101000000000
          lut[idx] = ->arm_branch(UInt32)
        elsif idx & 0b111000000000 == 0b100000000000
          lut[idx] = ->arm_block_data_transfer(UInt32)
        elsif idx & 0b111000000001 == 0b011000000001
          # undefined
        elsif idx & 0b110000000000 == 0b010000000000
          lut[idx] = ->arm_single_data_transfer(UInt32)
        elsif idx & 0b111111111111 == 0b000100100001
          lut[idx] = ->arm_branch_exchange(UInt32)
        elsif idx & 0b111110111111 == 0b000100001001
          lut[idx] = ->arm_single_data_swap(UInt32)
        elsif idx & 0b111110001111 == 0b000010001001
          lut[idx] = ->arm_multiply_long(UInt32)
        elsif idx & 0b111111001111 == 0b000000001001
          lut[idx] = ->arm_multiply(UInt32)
        elsif idx & 0b111001001001 == 0b000001001001
          lut[idx] = ->arm_UInt16_data_transfer_immediate(UInt32)
        elsif idx & 0b111001001001 == 0b000000001001
          lut[idx] = ->arm_UInt16_data_transfer_register(UInt32)
        elsif idx & 0b110110010000 == 0b000100000000
          lut[idx] = ->arm_psr_transfer(UInt32)
        elsif idx & 0b110000000000 == 0b000000000000
          lut[idx] = ->arm_data_processing(UInt32)
        else
          lut[idx] = ->arm_unused(UInt32)
        end
      end
      lut
    end

    def arm_unimplemented(instr : UInt32) : Nil
      abort "Unimplemented instruction: #{hex_str instr}"
    end

    def arm_unused(instr : UInt32) : Nil
      puts "Unused instruction: #{hex_str instr}"
    end

    def rotate_register(instr : UInt32, carry_out : Pointer(Bool), allow_register_shifts : Bool) : UInt32
      reg = bits(instr, 0..3)
      shift_type = bits(instr, 5..6)
      immediate = !(allow_register_shifts && bit?(instr, 4))
      if immediate
        shift_amount = bits(instr, 7..11)
      else
        shift_register = bits(instr, 8..11)
        # todo weird logic if bottom byte of reg > 31
        shift_amount = @r[shift_register] & 0xFF
      end
      case shift_type
      when 0b00 then lsl(@r[reg], shift_amount, carry_out)
      when 0b01 then lsr(@r[reg], shift_amount, immediate, carry_out)
      when 0b10 then asr(@r[reg], shift_amount, immediate, carry_out)
      when 0b11 then ror(@r[reg], shift_amount, immediate, carry_out)
      else           raise "Impossible shift type: #{hex_str shift_type}"
      end
    end

    def immediate_offset(instr : UInt32, carry_out : Pointer(Bool)) : UInt32
      rotate = bits(instr, 8..11)
      imm = bits(instr, 0..7)
      # todo putting "false" here causes the gba-suite tests to pass, but _why_
      ror(imm, rotate << 1, false, carry_out)
    end
  end
end
