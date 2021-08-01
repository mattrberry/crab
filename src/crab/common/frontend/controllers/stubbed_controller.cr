class StubbedController < Controller
  getter width : Int32 = 0
  getter height : Int32 = 0
  getter window_width : Int32 = 240
  getter window_height : Int32 = 160
  class_getter extensions = [] of String
  class_getter shader : String = "stubbed_colors.frag"

  def emu : Emu
    abort "Called emu method in StubbedController"
  end

  def initialize(*args, **kwargs)
  end

  # Control

  def run_until_frame : Nil
  end

  # Audio

  def sync? : Bool
    true
  end

  def toggle_sync : Nil
  end

  # Video

  def get_framebuffer : Slice(UInt16)
    Slice(UInt16).new 0
  end

  # Input

  def handle_controller_event(event : SDL::Event::JoyHat | SDL::Event::JoyButton) : Nil
  end

  def handle_input(input : Input, pressed : Bool) : Nil
  end
end
