abstract class Emu
  def post_init : Nil
  end

  abstract def scheduler : Scheduler
  abstract def run : Nil
  abstract def handle_event(event : SDL::Event) : Nil
  abstract def toggle_sync : Nil
  abstract def toggle_blending : Nil

  def handle_events(interval : Int) : Nil
    scheduler.schedule interval, Proc(Nil).new { handle_events interval }
    while event = SDL::Event.poll
      ImGui::SDL2.process_event(event)
      case event
      when SDL::Event::Quit then exit 0
      when SDL::Event::JoyHat,
           SDL::Event::JoyButton then handle_event(event)
      when SDL::Event::Keyboard
        case event.sym
        when .tab? then toggle_sync if event.pressed?
        when .m?   then toggle_blending if event.pressed?
        when .q?   then exit 0
        else            handle_event(event)
        end
      else nil
      end
    end
  end
end
