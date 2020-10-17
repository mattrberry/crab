class Keypad
  class KEYINPUT < BitField(UInt16)
    num not_used, 6
    bool l
    bool r
    bool down
    bool up
    bool left
    bool right
    bool start
    bool :select
    bool b
    bool a
  end

  class KEYCNT < BitField(UInt16)
    bool irq_condition
    bool irq_enable
    num not_used, 4
    bool l
    bool r
    bool down
    bool up
    bool left
    bool right
    bool start
    bool :select
    bool b
    bool a
  end

  @keyinput = KEYINPUT.new 0xFFFF_u16
  @keycnt = KEYCNT.new 0xFFFF_u16

  def read_io(io_addr : Int) : Byte
    case io_addr
    when 0x130 then 0xFF_u8 & @keyinput.value
    when 0x131 then 0xFF_u8 & @keyinput.value >> 8
    when 0x132 then 0xFF_u8 & @keycnt.value
    when 0x133 then 0xFF_u8 & @keycnt.value >> 8
    else            raise "Unimplemented keypad read ~ addr:#{hex_str io_addr.to_u8!}"
    end
  end

  def write_io(io_addr : Int, value : Byte) : Nil
    case io_addr
    when 0x130 then nil
    when 0x131 then nil
    else            raise "Unimplemented keypad write ~ addr:#{hex_str io_addr.to_u8!}, val:#{value}"
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
