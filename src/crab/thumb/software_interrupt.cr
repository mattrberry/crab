module THUMB
  def thumb_software_interrupt(instr : Word) : Nil
    lr = @r[15] - 4
    switch_mode CPU::Mode::SVC
    @r[14] = lr
    @cpsr.irq_disable = true
    @cpsr.thumb = false
    @r[15] = 0x08
    clear_pipeline
  end
end
