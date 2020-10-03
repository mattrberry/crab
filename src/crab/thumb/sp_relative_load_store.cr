module THUMB
  def thumb_sp_relative_load_store(instr : Word) : Nil
    load = bit?(instr, 11)
    rd = bits(instr, 8..10)
    word = bits(instr, 0..7)
    address = @r[13] &+ (word << 2)
    if load
      @r[rd] = @gba.bus.read_word(address)
    else
      @gba.bus[address] = @r[rd]
    end
  end
end
