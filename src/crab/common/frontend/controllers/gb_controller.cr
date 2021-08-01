class GBController < Controller
  getter emu : GB::GB
  class_getter extensions : Array(String) = ["gb", "gbc"]
  class_getter vertex_shader : String = "identity.vert"
  class_getter fragment_shader : String = "gb_colors.frag"

  getter width : Int32 = 160
  getter height : Int32 = 144

  def initialize(bios : String?, rom : String)
    @emu = GB::GB.new(bios || gbc_bios, rom, true, false)
    @emu.post_init
  end

  # Audio

  def sync? : Bool
    @emu.apu.sync
  end
end
