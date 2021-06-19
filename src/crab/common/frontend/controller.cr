abstract class Controller
  abstract def width : Int32
  abstract def height : Int32

  class_getter shader : String? = nil

  def get_framebuffer : Slice(UInt16)
    emu.ppu.framebuffer
  end

  def run_until_frame : Nil
    emu.run_until_frame
  end

  def handle_event(event : SDL::Event) : Nil
    emu.handle_event(event)
  end

  def toggle_sync : Nil
    emu.toggle_sync
  end
end
