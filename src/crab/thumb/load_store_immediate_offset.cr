module THUMB
  def thumb_load_store_immediate_offset(instr : Word) : Nil
    byte_quantity_and_load = bits(instr, 11..12)
    offset = bits(instr, 6..10)
    rb = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    imm = offset << 2
    address = @r[rb] &+ (offset << 2)
    case byte_quantity_and_load
    when 0b00 then @gba.bus[address] = @r[rd]
    when 0b01
      @r[rd] = @gba.bus.read_word(address)
      clear_pipeline if rd == 15
    when 0b10 then @gba.bus[address] = 0xFF_u8 & @r[rd]
    when 0b11
      @r[rd] = 0xFFFFFFFF_u32 & @gba.bus[address]
      clear_pipeline if rd == 15
    end
  end
end