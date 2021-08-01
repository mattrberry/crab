abstract class Controller
  abstract def emu : Emu

  # Window Config

  abstract def width : Int32
  abstract def height : Int32

  def render_menu : Nil
  end

  def render_windows : Nil
  end

  def window_width : Int32
    width
  end

  def window_height : Int32
    height
  end

  # Control

  def run_until_frame : Nil
    emu.run_until_frame
  end

  # Audio

  abstract def sync? : Bool

  def toggle_sync : Nil
    emu.toggle_sync
  end

  # Video

  def get_framebuffer : Slice(UInt16)
    emu.ppu.framebuffer
  end

  # Input

  def handle_controller_event(event : SDL::Event::JoyHat | SDL::Event::JoyButton) : Nil
    emu.handle_controller_event(event)
  end

  def handle_input(input : Input, pressed : Bool) : Nil
    emu.handle_input(input, pressed)
  end

  # Debug

  def render_debug_items : Nil
  end

  def render_windows : Nil
  end
end
