module GBA
  module THUMB
    def thumb_load_store_register_offset(instr : UInt32) : Nil
      load_and_byte_quantity = bits(instr, 10..11)
      ro = bits(instr, 6..8)
      rb = bits(instr, 3..5)
      rd = bits(instr, 0..2)
      address = @r[rb] &+ @r[ro]
      case load_and_byte_quantity
      when 0b00 then @gba.bus[address] = @r[rd]                      # str
      when 0b01 then @gba.bus[address] = @r[rd].to_u8!               # strb
      when 0b10 then set_reg(rd, @gba.bus.read_word_rotate(address)) # ldr
      when 0b11 then set_reg(rd, @gba.bus[address].to_u32!)          # ldrb
      end

      step_thumb
    end
  end
end
