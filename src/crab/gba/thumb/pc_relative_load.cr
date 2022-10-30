module GBA
  module THUMB
    def thumb_pc_relative_load(instr : UInt32) : Nil
      imm = bits(instr, 0..7)
      rd = bits(instr, 8..10)
      set_reg(rd, @gba.bus.read_word((@r[15] & ~2) &+ (imm << 2)))

      step_thumb
    end
  end
end
