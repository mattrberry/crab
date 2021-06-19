require "lib_gl"

abstract class Frontend
  def self.new(bios : String?, rom : String?, headless = false)
    if headless
      HeadlessFrontend.new(bios, rom)
    else
      SDLOpenGLImGuiFrontend.new(bios, rom)
    end
  end

  abstract def run : NoReturn

  private def init_controller(bios : String?, rom : String) : Controller
    extension = rom.rpartition('.')[2]
    if GBController.extensions.includes? extension
      controller = GBController.new(bios, rom)
    elsif GBAController.extensions.includes? extension
      controller = GBAController.new(bios, rom)
    else
      abort "Unsupported file extension: #{extension}"
    end
    controller
  end
end
