require "sdl"
require "./apu"
require "./cartridge"
require "./cpu"
require "./display"
require "./interrupts"
require "./joypad"
require "./mbc/*"
require "./memory"
require "./opcodes"
require "./ppu"
require "./scanline_ppu"
require "./fifo_ppu"
require "./scheduler"
require "./timer"

DISPLAY_SCALE = {% unless flag? :graphics_test %} 4 {% else %} 1 {% end %}

module GB
  class GB
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

    def initialize(@bootrom : String?, rom_path : String, @fifo : Bool, @sync : Bool, @headless : Bool)
      @cartridge = Cartridge.new rom_path
      @cgb_enabled = !(bootrom.nil? && @cartridge.cgb == Cartridge::CGB::NONE)

      SDL.init(SDL::Init::VIDEO | SDL::Init::AUDIO | SDL::Init::JOYSTICK)
      LibSDL.joystick_open 0
      at_exit { SDL.quit }
    end

    def post_init : Nil
      @scheduler = Scheduler.new
      @interrupts = Interrupts.new
      @apu = APU.new self, @headless, @sync
      @display = Display.new self, @headless
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

    def handle_events : Nil
      while event = SDL::Event.poll
        case event
        when SDL::Event::Quit then exit 0
        when SDL::Event::Keyboard,
             SDL::Event::JoyHat,
             SDL::Event::JoyButton then joypad.handle_joypad_event event
        else nil
        end
      end
      scheduler.schedule 70224, Scheduler::EventType::HandleInput, ->handle_events
    end

    def run : Nil
      handle_events
      loop do
        cpu.tick
      end
    end
  end
end
