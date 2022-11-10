module GBA
  module THUMB
    def thumb_load_store_halfword(instr : UInt32) : Nil
      load = bit?(instr, 11)
      offset = bits(instr, 6..10)
      rb = bits(instr, 3..5)
      rd = bits(instr, 0..2)
      address = @r[rb] + (offset << 1)
      if load
        set_reg(rd, @gba.bus.read_half_rotate(address))
      else
        @gba.bus[address] = @r[rd].to_u16!
      end

      step_thumb
    end
  end
end
