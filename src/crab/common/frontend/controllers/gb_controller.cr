class GBController < Controller
  getter emu : GB::GB
  class_getter extensions : Array(String) = ["gb", "gbc"]

  getter width : Int32 = 160
  getter height : Int32 = 144
  getter shader : String = "gb_colors.frag"

  def initialize(bios : String?, rom : String)
    @emu = GB::GB.new(bios, rom, true, false)
    @emu.post_init
  end
end
