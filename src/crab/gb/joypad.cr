module GB
  class Joypad
    property button_keys = false
    property direction_keys = false

    # describes if a button is CURRENTLY PRESSED
    property down = false
    property up = false
    property left = false
    property right = false
    property start = false
    property :select # select is a keyword
    @select = false
    property b = false
    property a = false

    def initialize(@gb : GB)
    end

    def read : UInt8
      array_to_uint8 [
        1,
        1,
        !@button_keys,
        !@direction_keys,
        !((@down && @direction_keys) || (@start && @button_keys)),
        !((@up && @direction_keys) || (@select && @button_keys)),
        !((@left && @direction_keys) || (@b && @button_keys)),
        !((@right && @direction_keys) || (@a && @button_keys)),
      ]
    end

    def write(value : UInt8) : Nil
      @button_keys = (value >> 5) & 0x1 == 0
      @direction_keys = (value >> 4) & 0x1 == 0
    end

    def handle_input(input : Input, pressed : Bool) : Nil
      case input
      in Input::UP          then @up = pressed
      in Input::DOWN        then @down = pressed
      in Input::LEFT        then @left = pressed
      in Input::RIGHT       then @right = pressed
      in Input::A           then @a = pressed
      in Input::B           then @b = pressed
      in Input::SELECT      then @select = pressed
      in Input::START       then @start = pressed
      in Input::L, Input::R then nil
      end
    end

    def handle_joypad_event(event : SDL::Event) : Nil
      case event
      when SDL::Event::Keyboard
        case event.sym
        when .down?, .d?  then @down = event.pressed?
        when .up?, .e?    then @up = event.pressed?
        when .left?, .s?  then @left = event.pressed?
        when .right?, .f? then @right = event.pressed?
        when .semicolon?  then @start = event.pressed?
        when .l?          then @select = event.pressed?
        when .b?, .j?     then @b = event.pressed?
        when .a?, .k?     then @a = event.pressed?
        else                   nil
        end
      when SDL::Event::JoyHat
        @down = false
        @up = false
        @left = false
        @right = false
        case event.value
        when LibSDL::HAT_DOWN      then @down = true
        when LibSDL::HAT_UP        then @up = true
        when LibSDL::HAT_LEFT      then @left = true
        when LibSDL::HAT_RIGHT     then @right = true
        when LibSDL::HAT_LEFTUP    then @left = @up = true
        when LibSDL::HAT_LEFTDOWN  then @left = @down = true
        when LibSDL::HAT_RIGHTUP   then @right = @up = true
        when LibSDL::HAT_RIGHTDOWN then @right = @down = true
        else                            nil
        end
      when SDL::Event::JoyButton
        case event.button
        when 7 then @start = event.pressed?
        when 6 then @select = event.pressed?
        when 0 then @b = event.pressed?
        when 1 then @a = event.pressed?
        else        nil
        end
      else nil
      end
    end
  end
end
