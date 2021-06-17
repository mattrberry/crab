class GBAccessor < Accessor
  getter width : Int32 = 160
  getter height : Int32 = 144
  getter shader : String = "gb_colors.frag"

  def initialize(@gb : GB::GB)
  end

  def get_framebuffer : Slice(UInt16)
    @gb.ppu.framebuffer
  end
end
