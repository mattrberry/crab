module THUMB
  def thumb_load_store_halfword(instr : Word) : Nil
    load = bit?(instr, 11)
    offset = bits(instr, 6..10)
    rb = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    address = @r[rb] + (offset << 1)
    if load
      @r[rd] = @gba.bus.read_half(address)
    else
      @gba.bus[address] = @r[rd].to_u16!
    end
  end
end
