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
    getter! ppu : PPU
    getter! apu : APU
    getter! dma : DMA
    getter! debugger : Debugger

    def initialize(@bios_path : String, @rom_path : String)
      @scheduler = Scheduler.new
      @cartridge = Cartridge.new @rom_path
      scheduler.schedule 280896, ->handle_saves
    end

    def post_init : Nil
      @storage = Storage.new self, @rom_path
      @mmio = MMIO.new self
      @timer = Timer.new self
      @keypad = Keypad.new self
      @bus = Bus.new self, @bios_path
      @interrupts = Interrupts.new self
      @cpu = CPU.new self
      @ppu = PPU.new self
      @apu = APU.new self
      @dma = DMA.new self
      @debugger = Debugger.new self
    end

    def run_until_frame : Nil
      until ppu.frame
        cpu.tick
      end
      ppu.frame = false
    end

    def handle_event(event : SDL::Event) : Nil
      keypad.handle_keypad_event event
    end

    def handle_input(input : Input, pressed : Bool) : Nil
      keypad.handle_input(input, pressed)
    end

    def toggle_sync : Nil
      apu.toggle_sync
    end

    def handle_saves : Nil
      scheduler.schedule 280896, ->handle_saves
      storage.write_save
    end
  end
end
