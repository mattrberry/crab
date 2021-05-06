module GBA
  module THUMB
    def thumb_unconditional_branch(instr : Word) : Nil
      offset = bits(instr, 0..10)
      offset = (offset << 5).to_i16! >> 4
      set_reg(15, @r[15] &+ offset)
    end
  end
end
