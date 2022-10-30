{% if flag?(:release) %}
  # Disables bounds checking in release mode.

  struct Slice(T)
    @[AlwaysInline]
    def []=(index : Int, value : T) : T
      @pointer[index] = value
    end

    @[AlwaysInline]
    def [](index : Int) : T
      @pointer[index]
    end
  end
{% end %}

require "colorize"
require "option_parser"

require "bitfield"
require "sdl"

require "./crab/common/*"
require "./crab/common/frontend/*"
require "./crab/gb"
require "./crab/gba"

Colorize.on_tty_only!

module Crab
  VERSION = "0.1.0"

  extend self

  def run : NoReturn
    config = Config.new

    rom = nil
    bios = nil

    OptionParser.parse do |parser|
      parser.banner = "#{"crab".colorize.bold} - An accurate and readable Game Boy (Color) (Advance) emulator"
      parser.separator
      parser.separator("Usage: bin/crab [BIOS] [ROM]")
      parser.separator
      parser.separator("All command-line arguments serve as optional overrides to the config.")
      parser.on("-h", "--help", "Show the help message") do
        puts parser
        exit
      end
      parser.on("--run-bios", "Run the bios on startup") { config.args.run_bios = true }
      parser.on("--skip-bios", "Skip the bios on startup") { config.args.run_bios = false }
      parser.on("--fifo", "Enable per-pixel rendering for GBC") { config.args.fifo = true }
      parser.on("--scanline", "Enable scanline rendering for GBC") { config.args.fifo = false }
      parser.on("--headless", "Don't open window or play audio") { config.args.headless = true }
      parser.unknown_args do |args|
        case args.size
        when 0 # launch the emulator without a rom selected
        when 1 then rom = args[0]
        when 2 then bios, rom = args[0], args[1]
        else        abort "Unknown args #{args[2..]}. Use '--help' for help"
        end
      end
      parser.invalid_option { |flag| abort "Unknown flag '#{flag}'. Use '--help' for help" }
      parser.missing_option { |flag| abort "Option '#{flag}' is missing a value. Use '--help' for help" }
    end

    frontend = Frontend.new(config, bios, rom)
    frontend.run
  end
end

unless PROGRAM_NAME.includes?("crystal-run-spec")
  Crab.run
end
