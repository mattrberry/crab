module THUMB
  def thumb_load_store_immediate_offset(instr : Word) : Nil
    byte_quantity_and_load = bits(instr, 11..12)
    offset = bits(instr, 6..10)
    rb = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    imm = offset << 2
    case byte_quantity_and_load
    when 0b00 then @gba.bus[@r[rb] + imm] = @r[rd]
    when 0b01 then @r[rd] = @gba.bus.read_word(@r[rb] + imm)
    when 0b10 then @gba.bus[@r[rb] + imm] = @r[rd].to_u8!
    when 0b11 then @r[rd] = @gba.bus[@r[rb] + imm].to_u32
    end
  end
end
