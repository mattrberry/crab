require "colorize"
require "option_parser"

require "bitfield"
require "sdl"
require "imgui"
require "imgui-backends"
require "imgui-backends/lib"

require "./crab/common/*"

require "./crab/common/frontend/*"
require "./crab/gb"
require "./crab/gba"

Colorize.on_tty_only!

module Crab
  VERSION = "0.1.0"

  extend self

  def run
    rom = nil
    bios = nil
    fifo = false
    headless = false

    OptionParser.parse do |parser|
      parser.banner = "#{"crab".colorize.bold} - An accurate and readable Game Boy (Color) (Advance) emulator"
      parser.separator
      parser.separator("Usage: bin/crab [BIOS] ROM")
      parser.separator
      parser.on("-h", "--help", "Show the help message") do
        puts parser
        exit
      end
      parser.on("--fifo", "Enable FIFO rendering") { fifo = true }
      parser.on("--headless", "Don't open window or play audio") { headless = true }
      parser.unknown_args do |args|
        case args.size
        when 1 then rom = args[0]
        when 2 then bios, rom = args[0], args[1]
        end
        abort parser if rom.nil?
        abort "GBA ROMs need a bios provided" if rom.not_nil!.ends_with?(".gba") && bios.nil?
      end
    end

    if rom.not_nil!.ends_with?(".gba")
      emu = GBA::GBA.new bios.not_nil!, rom.not_nil!
    else
      emu = GB::GB.new bios, rom.not_nil!, fifo, headless
    end
    emu.post_init

    frontend = Frontend.new(emu)
    frontend.run
  end
end

unless PROGRAM_NAME.includes?("crystal-run-spec")
  Crab.run
end
