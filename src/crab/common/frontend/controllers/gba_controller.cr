class GBAController < Controller
  getter emu : GBA::GBA
  class_getter extensions : Array(String) = ["gba"]
  class_getter shader : String? = "gba_colors.frag"

  getter width : Int32 = 240
  getter height : Int32 = 160

  def initialize(bios : String?, rom : String)
    @emu = GBA::GBA.new("/home/matt/Downloads/gba/gba_bios.bin", rom)
    @emu.post_init
  end
end