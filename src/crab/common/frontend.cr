abstract class Frontend
  def self.new(config : Config, bios : String?, rom : String?)
    if config.args.headless
      HeadlessFrontend.new(config, bios, rom)
    else
      SDLOpenGLImGuiFrontend.new(config, bios, rom)
    end
  end

  abstract def run : NoReturn

  private def init_controller(bios : String?, rom : String?, skip_bios : Bool) : Controller
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
