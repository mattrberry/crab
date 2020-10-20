require "bitfield"
require "sdl"

require "./crab/gba"

module Crab
  VERSION = "0.1.0"

  extend self

  def run
    gba = GBA.new ARGV[0], ARGV[1]
    gba.run
  end
end

unless PROGRAM_NAME.includes?("crystal-run-spec")
  Crab.run
end
