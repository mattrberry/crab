module GBA
  module THUMB
    def thumb_load_store_immediate_offset(instr : UInt32) : Nil
      byte_quantity_and_load = bits(instr, 11..12)
      offset = bits(instr, 6..10)
      rb = bits(instr, 3..5)
      rd = bits(instr, 0..2)
      base_address = @r[rb]
      case byte_quantity_and_load
      when 0b00 then @gba.bus[base_address &+ (offset << 2)] = @r[rd]                      # str
      when 0b01 then set_reg(rd, @gba.bus.read_word_rotate(base_address &+ (offset << 2))) # ldr
      when 0b10 then @gba.bus[base_address &+ offset] = @r[rd].to_u8!                      # strb
      when 0b11 then set_reg(rd, @gba.bus[base_address &+ offset].to_u32)                  # ldrb
      end

      step_thumb
    end
  end
end
