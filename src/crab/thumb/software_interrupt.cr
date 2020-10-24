module THUMB
  def thumb_software_interrupt(instr : Word) : Nil
    lr = @r[15] - 4
    switch_mode CPU::Mode::SVC
    set_reg(14, lr)
    @cpsr.irq_disable = true
    @cpsr.thumb = false
    set_reg(15, 0x08)
  end
end
