require "./types"
require "./reg"
require "./cartridge"
require "./storage"
require "./storage/*"
require "./mmio"
require "./timer"
require "./keypad"
require "./bus"
require "./interrupts"
require "./cpu"
require "./ppu"
require "./apu"
require "./dma"
require "./debugger"

module GBA
  class GBA < Emu
    getter! scheduler : Scheduler
    getter! cartridge : Cartridge
    getter! storage : Storage
    getter! mmio : MMIO
    getter! timer : Timer
    getter! keypad : Keypad
    getter! bus : Bus
    getter! interrupts : Interrupts
    getter! cpu : CPU
    getter! display : Display
    getter! ppu : PPU
    getter! apu : APU
    getter! dma : DMA
    getter! debugger : Debugger

    def initialize(@bios_path : String, rom_path : String)
      @scheduler = Scheduler.new
      @cartridge = Cartridge.new rom_path
      @storage = Storage.new rom_path
      handle_saves

      SDL.init(SDL::Init::VIDEO | SDL::Init::AUDIO | SDL::Init::JOYSTICK)
      LibSDL.joystick_open 0
      at_exit { SDL.quit }
    end

    def post_init : Nil
      @mmio = MMIO.new self
      @timer = Timer.new self
      @keypad = Keypad.new self
      @bus = Bus.new self, @bios_path
      @interrupts = Interrupts.new self
      @cpu = CPU.new self
      @display = Display.new Display::Console::GBA
      @ppu = PPU.new self
      @apu = APU.new self
      @dma = DMA.new self
      @debugger = Debugger.new self
    end

    def run : Nil
      handle_events(280896)
      loop do
        {% if flag? :debugger %} debugger.check_debug {% end %}
        cpu.tick
      end
    end

    def handle_event(event : SDL::Event) : Nil
      keypad.handle_keypad_event event
    end

    def toggle_sync : Nil
      apu.toggle_sync
    end

    def toggle_blending : Nil
      display.toggle_blending
    end

    def handle_saves : Nil
      scheduler.schedule 280896, ->handle_saves
      storage.write_save
    end
  end
end
