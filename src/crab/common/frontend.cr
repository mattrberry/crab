require "lib_gl"

abstract class Frontend
  def self.new(emu : Emu, headless = false)
    if headless
      HeadlessFrontend.new(emu)
    else
      SDLOpenGLImGuiFrontend.new(emu)
    end
  end

  abstract def run : NoReturn
end
