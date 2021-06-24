class GBController < Controller
  getter emu : GB::GB
  class_getter extensions : Array(String) = ["gb", "gbc"]
  class_getter shader : String? = "gb_colors.frag"

  getter width : Int32 = 160
  getter height : Int32 = 144

  getter name : String = "Game Boy (Color)"

  def initialize(bios : String?, rom : String)
    @emu = GB::GB.new(bios, rom, true, false)
    @emu.post_init
  end

  def actions(& : Action ->)
    yield Action.new("Sync", ->@emu.toggle_sync, emu.apu.sync)
  end
end
