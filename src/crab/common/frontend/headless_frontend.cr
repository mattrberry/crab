class HeadlessFrontend < Frontend
  @controller : Controller

  def initialize(bios : String?, rom : String?)
    @controller = init_controller(bios, rom.not_nil!)
  end

  def run : NoReturn
    loop do
      @controller.run_until_frame
    end
  end
end
