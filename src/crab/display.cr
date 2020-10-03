class Display
  WIDTH  = 240
  HEIGHT = 160
  SCALE  =   4

  PIXELFORMAT_RGB24       = (1 << 28) | (7 << 24) | (1 << 20) | (0 << 16) | (24 << 8) | (3 << 0)
  PIXELFORMAT_BGR555      = (1 << 28) | (5 << 24) | (5 << 20) | (3 << 16) | (15 << 8) | (2 << 0)
  TEXTUREACCESS_STREAMING = 1

  def initialize
    @window = SDL::Window.new("crab", WIDTH * SCALE, HEIGHT * SCALE)
    @renderer = SDL::Renderer.new @window
    @renderer.logical_size = {WIDTH, HEIGHT}
    @texture = LibSDL.create_texture @renderer, PIXELFORMAT_BGR555, TEXTUREACCESS_STREAMING, WIDTH, HEIGHT
  end

  def draw(framebuffer : Bytes) : Nil
    LibSDL.update_texture @texture, nil, framebuffer, WIDTH * 2
    @renderer.clear
    @renderer.copy @texture
    @renderer.present
  end
end
