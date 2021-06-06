module GBA
  module THUMB
    def thumb_multiple_load_store(instr : Word) : Nil
      load = bit?(instr, 11)
      rb = bits(instr, 8..10)
      list = bits(instr, 0..7)
      set_reg(rb, address + list.popcount * 4)
      address = @r[rb]
      unless list == 0
        if load # ldmia
          8.times do |idx|
            if bit?(list, idx)
              set_reg(idx, @gba.bus.read_word(address))
              address &+= 4
            end
          end
        else # stmia
          base_addr = nil
          8.times do |idx|
            if bit?(list, idx)
              @gba.bus[address] = @r[idx]
              base_addr = address if rb == idx
              address &+= 4
            end
          end
          @gba.bus[base_addr] = address if base_addr && first_set_bit(list) != rb # rb is written after first store
        end
      else # https://github.com/jsmolka/gba-suite/blob/0e32e15c6241e6dc20851563ba88f4656ac50936/thumb/memory.asm#L459
        if load
          set_reg(15, @gba.bus.read_word(address))
        else
          @gba.bus[address] = @r[15] &+ 2
        end
        set_reg(rb, address &+ 0x40)
      end

      step_thumb unless list == 0 && load
    end
  end
end
