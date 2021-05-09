# define a new CPU with the given bytes as rom
def new_cpu(bytes : Array(Int), cgb_enabled = true, boot = false)
  interrupts = Interrupts.new
  display = Display.new
  ppu = PPU.new display, interrupts, pointerof(cgb_enabled)
  apu = APU.new
  timer = Timer.new interrupts

  cpu = CPU.new new_memory(bytes), interrupts, ppu, apu, timer, boot
  cpu.sp = 0xFFFE_u16
  cpu
end

# define a new Memory with the given bytes as rom
def new_memory(bytes : Array(Int), cgb_enabled = true, bootrom = nil)
  rom = Bytes.new 0x8000
  bytes.each_with_index do |byte, i|
    rom[i] = byte.to_u8!
  end
  cartridge = GB::Cartridge.new rom
  interrupts = GB::Interrupts.new
  display = GB::Display.new
  ppu = GB::PPU.new display, interrupts, pointerof(cgb_enabled)
  apu = GB::APU.new
  timer = GB::Timer.new interrupts
  joypad = GB::Joypad.new
  GB::Memory.new cartridge, interrupts, ppu, apu, timer, joypad, pointerof(cgb_enabled), bootrom
end
