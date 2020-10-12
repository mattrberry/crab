module THUMB
  def thumb_multiple_load_store(instr : Word) : Nil
    load = bit?(instr, 11)
    rb = bits(instr, 8..10)
    list = bits(instr, 0..7)
    address = @r[rb]
    if load # ldmia
      8.times do |idx|
        if bit?(list, idx)
          @r[idx] = @gba.bus.read_word(address)
          address &+= 4
        end
      end
    else # stmia
      7.downto(0).each do |idx|
        if bit?(list, idx)
          @gba.bus[address] = @r[idx]
          address &+= 4
        end
      end
    end
    @r[rb] = address
  end
end
