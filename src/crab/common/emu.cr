abstract class Emu
  def post_init : Nil
  end

  abstract def scheduler : Scheduler
  abstract def run_until_frame : Nil
  abstract def handle_controller_event(event : SDL::Event::JoyHat | SDL::Event::JoyButton) : Nil
  abstract def toggle_sync : Nil
end
