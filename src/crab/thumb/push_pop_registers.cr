module THUMB
  def thumb_push_pop_registers(instr : Word) : Nil
    pop = bit?(instr, 11)
    pclr = bit?(instr, 8)
    list = bits(instr, 0..7)
    address = @r[13]
    if pop
      8.times do |idx|
        if bit?(list, idx)
          set_reg(idx, @gba.bus.read_word(address))
          address &+= 4
        end
      end
      if pclr
        set_reg(15, @gba.bus.read_word(address))
        address &+= 4
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
    set_reg(13, address)

    step_thumb unless pop && pclr
  end
end
