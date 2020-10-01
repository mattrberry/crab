require "./types"
require "./util"
require "./cartridge"
require "./bus"
require "./cpu"
require "./ppu"

class GBA
  getter cartridge : Cartridge
  getter bus : Bus { Bus.new self }
  getter cpu : CPU { CPU.new self }
  getter ppu : PPU { PPU.new self }

  def initialize(rom_path : String)
    @cartridge = Cartridge.new rom_path
  end

  def run : Nil
    # puts @cartridge.title
    loop do
      cpu.tick
    end
  end
end
