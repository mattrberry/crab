require "./types"
require "./util"
require "./cartridge"
require "./bus"
require "./cpu"
require "./display"
require "./ppu"

class GBA
  getter cartridge : Cartridge
  getter bus : Bus { Bus.new self }
  getter cpu : CPU { CPU.new self }
  getter display : Display { Display.new }
  getter ppu : PPU { PPU.new self }

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
    # puts @cartridge.title
    loop do
      280896.times do
        cpu.tick
      end
      ppu.tick 280896
      handle_events
    end
  end
end
