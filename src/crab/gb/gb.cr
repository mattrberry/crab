require "sdl"
require "./apu"
require "./cartridge"
require "./cpu"
require "./interrupts"
require "./joypad"
require "./mbc/*"
require "./memory"
require "./opcodes"
require "./ppu"
require "./scanline_ppu"
require "./fifo_ppu"
require "./timer"

module GB
  class GB < Emu
    getter bootrom : String?
    @cgb_enabled : Bool
    getter cgb_ptr : Pointer(Bool)
    getter cartridge : Cartridge

    getter! apu : APU
    getter! cpu : CPU
    getter! interrupts : Interrupts
    getter! joypad : Joypad
    getter! memory : Memory
    getter! ppu : PPU
    getter! scheduler : Scheduler
    getter! timer : Timer

    def initialize(@bootrom : String?, rom_path : String, @fifo : Bool, @headless : Bool, @run_bios : Bool)
      @cartridge = Cartridge.new rom_path
      @cgb_enabled = (!bootrom.nil? && @run_bios) || @cartridge.cgb != Cartridge::CGB::NONE
      @cgb_ptr = pointerof(@cgb_enabled)
    end

    def post_init : Nil
      @scheduler = Scheduler.new
      @interrupts = Interrupts.new
      @apu = APU.new self, @headless
      @joypad = Joypad.new self
      @ppu = @fifo ? FifoPPU.new self : ScanlinePPU.new self
      @timer = Timer.new self
      @memory = Memory.new self
      @cpu = CPU.new self

      skip_boot if @bootrom.nil? || !@run_bios
    end

    private def skip_boot : Nil
      cpu.skip_boot
      memory.skip_boot
      ppu.skip_boot
      timer.skip_boot
    end

    def run_until_frame : Nil
      until ppu.frame
        cpu.tick
      end
      ppu.frame = false
    end

    def handle_controller_event(event : SDL::Event::JoyHat | SDL::Event::JoyButton) : Nil
      joypad.handle_joypad_event event
    end

    def handle_input(input : Input, pressed : Bool) : Nil
      joypad.handle_input(input, pressed)
    end

    def toggle_sync : Nil
      apu.toggle_sync
    end
  end
end
