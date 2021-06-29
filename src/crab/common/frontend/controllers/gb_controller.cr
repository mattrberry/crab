class GBController < Controller
  getter emu : GB::GB
  class_getter extensions : Array(String) = ["gb", "gbc"]
  class_getter shader : String? = "gb_colors.frag"

  getter width : Int32 = 160
  getter height : Int32 = 144

  def initialize(bios : String?, rom : String)
    @emu = GB::GB.new(bios || gbc_bios, rom, true, false)
    @emu.post_init
  end

  def render_menu : Nil
    if ImGui.begin_menu "Game Boy (Color)"
      @emu.toggle_sync if ImGui.menu_item("Audio Sync", "", emu.apu.sync)
      ImGui.end_menu
    end
  end
end
