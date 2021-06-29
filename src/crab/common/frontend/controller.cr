abstract class Controller
  alias Action = Tuple(String, Proc(Nil), Bool)

  abstract def emu : Emu

  abstract def width : Int32
  abstract def height : Int32

  def render_menu : Nil
  end

  def render_windows : Nil
  end

  getter actions = [] of Action

  def window_width : Int32
    width
  end

  def window_height : Int32
    height
  end

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
