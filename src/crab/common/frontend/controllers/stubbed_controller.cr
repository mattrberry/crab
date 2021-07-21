class StubbedController < Controller
  getter width : Int32 = 0
  getter height : Int32 = 0
  getter window_width : Int32 = 240
  getter window_height : Int32 = 160
  class_getter extensions = [] of String

  def emu : Emu
    abort "Called emu method in StubbedController"
  end

  def initialize(*args, **kwargs)
  end

  def get_framebuffer : Slice(UInt16)
    Slice(UInt16).new 0
  end

  def run_until_frame : Nil
  end

  def handle_controller_event(event : SDL::Event::JoyHat | SDL::Event::JoyButton) : Nil
  end

  def handle_input(input : Input, pressed : Bool) : Nil
  end

  def toggle_sync : Nil
  end

  def actions(& : Action ->)
  end
end
