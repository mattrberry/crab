require "bitfield"

require "./crab/gba"

module Crab
  VERSION = "0.1.0"

  extend self

  def run
    gba = GBA.new ARGV[0]
    gba.run
  end
end

unless PROGRAM_NAME.includes?("crystal-run-spec")
  Crab.run
end
