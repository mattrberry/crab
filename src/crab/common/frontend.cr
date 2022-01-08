abstract class Frontend
  def self.new(bios : String?, rom : String?, headless = false)
    config = Config.new
    if headless
      HeadlessFrontend.new(config, bios, rom)
    else
      SDLOpenGLImGuiFrontend.new(config, bios, rom)
    end
  end

  abstract def run : NoReturn

  private def init_controller(bios : String?, rom : String?) : Controller
    return StubbedController.new unless rom
    extension = rom.rpartition('.')[2]
    if GBController.extensions.includes? extension
      GBController.new(@config, bios, rom)
    elsif GBAController.extensions.includes? extension
      GBAController.new(@config, bios, rom)
    else
      abort "Unsupported file extension: #{extension}"
    end
  end
end
