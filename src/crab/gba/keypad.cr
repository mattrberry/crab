module GBA
  class Keypad
    @keyinput = Reg::KEYINPUT.new 0xFFFF_u16
    @keycnt = Reg::KEYCNT.new 0xFFFF_u16

    def initialize(@gba : GBA)
    end

    def [](io_addr : Int) : Byte
      case io_addr
      when 0x130..0x131 then @keyinput.read_byte(io_addr & 1)
      when 0x132..0x133 then @keycnt.read_byte(io_addr & 1)
      else                   abort "Unreachable keypad read #{hex_str io_addr}"
      end
    end

    def []=(io_addr : Int, value : Byte) : Nil
      puts "TODO: Implement stopping and keycnt behavior" if 0x132 <= io_addr <= 0x133
    end

    def handle_input(input : Input, pressed : Bool) : Nil
      case input
      in Input::UP     then @keyinput.up = !pressed
      in Input::DOWN   then @keyinput.down = !pressed
      in Input::LEFT   then @keyinput.left = !pressed
      in Input::RIGHT  then @keyinput.right = !pressed
      in Input::A      then @keyinput.a = !pressed
      in Input::B      then @keyinput.b = !pressed
      in Input::SELECT then @keyinput.select = !pressed
      in Input::START  then @keyinput.start = !pressed
      in Input::L      then @keyinput.l = !pressed
      in Input::R      then @keyinput.r = !pressed
      end
    end

    def handle_keypad_event(event : SDL::Event) : Nil
      case event
      when SDL::Event::Keyboard
        bit = !event.pressed?
        case event.sym
        when .down?, .d?  then @keyinput.down = bit
        when .up?, .e?    then @keyinput.up = bit
        when .left?, .s?  then @keyinput.left = bit
        when .right?, .f? then @keyinput.right = bit
        when .semicolon?  then @keyinput.start = bit
        when .l?          then @keyinput.select = bit
        when .b?, .j?     then @keyinput.b = bit
        when .a?, .k?     then @keyinput.a = bit
        when .w?          then @keyinput.l = bit
        when .r?          then @keyinput.r = bit
        else                   nil
        end
      when SDL::Event::JoyHat
        @keyinput.value |= 0x00F0
        case event.value
        when LibSDL::HAT_DOWN      then @keyinput.down = false
        when LibSDL::HAT_UP        then @keyinput.up = false
        when LibSDL::HAT_LEFT      then @keyinput.left = false
        when LibSDL::HAT_RIGHT     then @keyinput.right = false
        when LibSDL::HAT_LEFTUP    then @keyinput.left = true; @keyinput.up = true
        when LibSDL::HAT_LEFTDOWN  then @keyinput.left = true; @keyinput.down = true
        when LibSDL::HAT_RIGHTUP   then @keyinput.right = true; @keyinput.up = true
        when LibSDL::HAT_RIGHTDOWN then @keyinput.right = true; @keyinput.down = true
        else                            nil
        end
      when SDL::Event::JoyButton
        bit = !event.pressed?
        case event.button
        when 0 then @keyinput.b = bit
        when 1 then @keyinput.a = bit
        when 4 then @keyinput.l = bit
        when 5 then @keyinput.r = bit
        when 6 then @keyinput.select = bit
        when 7 then @keyinput.start = bit
        else        nil
        end
      else nil
      end
    end
  end
end
