module GBA
  module ARM
    def arm_branch_exchange(instr : Word) : Nil
      address = @r[bits(instr, 0..3)]
      @cpsr.thumb = bit?(address, 0)
      set_reg(15, address)
    end
  end
end
