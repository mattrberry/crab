require "./types"
require "./util"
require "./cartridge"
require "./mmio"
require "./bus"
require "./interrupts"
require "./cpu"
require "./display"
require "./ppu"

class GBA
  getter cartridge : Cartridge
  getter mmio : MMIO { MMIO.new self }
  getter bus : Bus { Bus.new self }
  getter interrupts : Interrupts { Interrupts.new }
  getter cpu : CPU { CPU.new self }
  getter display : Display { Display.new }
  getter ppu : PPU { PPU.new self }

  @cycles = 0

  def initialize(rom_path : String)
    @cartridge = Cartridge.new rom_path

    SDL.init(SDL::Init::VIDEO | SDL::Init::AUDIO | SDL::Init::JOYSTICK)
    LibSDL.joystick_open 0
    at_exit { SDL.quit }
  end

  def handle_events : Nil
    while event = SDL::Event.poll
      case event
      when SDL::Event::Quit then exit 0
      when SDL::Event::Keyboard,
           SDL::Event::JoyHat,
           SDL::Event::JoyButton
      else nil
      end
    end
  end

  def run : Nil
    loop do
      cpu.tick
    end
  end

  def tick(cycles : Int) : Nil
    ppu.tick cycles
    @cycles += cycles
    if @cycles >= PPU::REFRESH
      handle_events
      @cycles -= PPU::REFRESH
    end
  end
end
