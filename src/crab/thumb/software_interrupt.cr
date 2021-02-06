module THUMB
  macro thumb_software_interrupt
    ->(gba : GBA, instr : Word) {
    lr = gba.cpu.r[15] - 2
    gba.cpu.switch_mode CPU::Mode::SVC
    gba.cpu.set_reg(14, lr)
    gba.cpu.cpsr.irq_disable = true
    gba.cpu.cpsr.thumb = false
    gba.cpu.set_reg(15, 0x08)
  }
  end
end
