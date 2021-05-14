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
    getter cgb_ptr : Pointer(Bool) { pointerof(@cgb_enabled) }
    getter cartridge : Cartridge

    getter! apu : APU
    getter! cpu : CPU
    getter! display : Display
    getter! interrupts : Interrupts
    getter! joypad : Joypad
    getter! memory : Memory
    getter! ppu : PPU
    getter! scheduler : Scheduler
    getter! timer : Timer

    def initialize(@bootrom : String?, rom_path : String, @fifo : Bool, @headless : Bool)
      @cartridge = Cartridge.new rom_path
      @cgb_enabled = !(bootrom.nil? && @cartridge.cgb == Cartridge::CGB::NONE)

      SDL.init(SDL::Init::VIDEO | SDL::Init::AUDIO | SDL::Init::JOYSTICK)
      LibSDL.joystick_open 0
      at_exit { SDL.quit }
    end

    def post_init : Nil
      @scheduler = Scheduler.new
      @interrupts = Interrupts.new
      @apu = APU.new self, @headless
      @display = Display.new Display::Console::GB, @headless
      @joypad = Joypad.new self
      @ppu = @fifo ? FifoPPU.new self : ScanlinePPU.new self
      @timer = Timer.new self
      @memory = Memory.new self
      @cpu = CPU.new self
      skip_boot if @bootrom.nil?
    end

    private def skip_boot : Nil
      cpu.skip_boot
      memory.skip_boot
      ppu.skip_boot
      timer.skip_boot
    end

    def run : Nil
      handle_events(70224)
      loop do
        cpu.tick
      end
    end

    def handle_event(event : SDL::Event) : Nil
      joypad.handle_joypad_event event
    end

    def toggle_sync : Nil
      apu.toggle_sync
    end

    def toggle_blending : Nil
      puts "Blending not implemented for gb/gbc"
    end
  end
end
