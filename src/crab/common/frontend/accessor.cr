abstract class Accessor
  abstract def width : Int32
  abstract def height : Int32
  abstract def shader : String

  abstract def get_framebuffer : Slice(UInt16)
end
