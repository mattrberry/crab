class HeadlessFrontend < Frontend
  def initialize(@emu : Emu)
  end

  def run : NoReturn
    loop do
      @emu.run_until_frame
    end
  end
end
