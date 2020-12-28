require "colorize"

require "bitfield"
require "sdl"

require "./crab/gba"

Colorize.on_tty_only!

module Crab
  VERSION = "0.1.0"

  extend self

  def run
    gba = GBA.new ARGV[0], ARGV[1]
    gba.post_init
    gba.run
  end
end

unless PROGRAM_NAME.includes?("crystal-run-spec")
  Crab.run
end
