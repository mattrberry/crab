module THUMB
  def thumb_push_pop_registers(instr : Word) : Nil
    pop = bit?(instr, 11)
    pclr = bit?(instr, 8)
    list = bits(instr, 0..7)
    address = @r[13]
    if pop
      8.times do |idx|
        if bit?(list, idx)
          @r[idx] = @gba.bus.read_word(address)
          address &+= 4
        end
      end
      if pclr
        @r[15] = @gba.bus.read_word(address)
        address &+= 4
        clear_pipeline
      end
    else
      if pclr
        address &-= 4
        @gba.bus[address] = @r[14]
      end
      7.downto(0).each do |idx|
        if bit?(list, idx)
          address &-= 4
          @gba.bus[address] = @r[idx]
        end
      end
    end
    @r[13] = address
  end
end
