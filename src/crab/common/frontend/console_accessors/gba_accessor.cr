class GBAAccessor < Accessor
  getter width : Int32 = 240
  getter height : Int32 = 160
  getter shader : String = "gba_colors.frag"

  def initialize(@gba : GBA::GBA)
  end

  def get_framebuffer : Slice(UInt16)
    @gba.ppu.framebuffer
  end
end
