module GB
  class Interrupts
    enum InterruptLine : UInt16
      VBLANK = 0x0040
      STAT   = 0x0048
      TIMER  = 0x0050
      SERIAL = 0x0058
      JOYPAD = 0x0060
      NONE   = 0x0000
    end

    @top_3_ie_bits : UInt8 = 0x00 # they're writable for some reason

    property vblank_interrupt = false
    property lcd_stat_interrupt = false
    property timer_interrupt = false
    property serial_interrupt = false
    property joypad_interrupt = false

    property vblank_enabled = false
    property lcd_stat_enabled = false
    property timer_enabled = false
    property serial_enabled = false
    property joypad_enabled = false

    def highest_priority : InterruptLine
      if vblank_interrupt && vblank_enabled
        InterruptLine::VBLANK
      elsif lcd_stat_interrupt && lcd_stat_enabled
        InterruptLine::STAT
      elsif timer_interrupt && timer_enabled
        InterruptLine::TIMER
      elsif serial_interrupt && serial_enabled
        InterruptLine::SERIAL
      elsif joypad_interrupt && joypad_enabled
        InterruptLine::JOYPAD
      else
        InterruptLine::NONE
      end
    end

    def clear(interrupt_line : InterruptLine) : Nil
      case interrupt_line
      in InterruptLine::VBLANK then @vblank_interrupt = false
      in InterruptLine::STAT   then @lcd_stat_interrupt = false
      in InterruptLine::TIMER  then @timer_interrupt = false
      in InterruptLine::SERIAL then @serial_interrupt = false
      in InterruptLine::JOYPAD then @joypad_interrupt = false
      in InterruptLine::NONE   then nil
      end
    end

    def interrupt_ready? : Bool
      self[0xFF0F] & self[0xFFFF] & 0x1F > 0
    end

    # read from interrupts memory
    def [](index : Int) : UInt8
      case index
      when 0xFF0F
        0xE0_u8 |
          (@joypad_interrupt ? (0x1 << 4) : 0) |
          (@serial_interrupt ? (0x1 << 3) : 0) |
          (@timer_interrupt ? (0x1 << 2) : 0) |
          (@lcd_stat_interrupt ? (0x1 << 1) : 0) |
          (@vblank_interrupt ? (0x1 << 0) : 0)
      when 0xFFFF
        @top_3_ie_bits |
          (@joypad_enabled ? (0x1 << 4) : 0) |
          (@serial_enabled ? (0x1 << 3) : 0) |
          (@timer_enabled ? (0x1 << 2) : 0) |
          (@lcd_stat_enabled ? (0x1 << 1) : 0) |
          (@vblank_enabled ? (0x1 << 0) : 0)
      else raise "Reading from invalid interrupts register: #{hex_str index.to_u16!}"
      end
    end

    # write to interrupts memory
    def []=(index : Int, value : UInt8) : Nil
      case index
      when 0xFF0F
        @vblank_interrupt = value & (0x1 << 0) > 0
        @lcd_stat_interrupt = value & (0x1 << 1) > 0
        @timer_interrupt = value & (0x1 << 2) > 0
        @serial_interrupt = value & (0x1 << 3) > 0
        @joypad_interrupt = value & (0x1 << 4) > 0
      when 0xFFFF
        @top_3_ie_bits = value & 0xE0
        @vblank_enabled = value & (0x1 << 0) > 0
        @lcd_stat_enabled = value & (0x1 << 1) > 0
        @timer_enabled = value & (0x1 << 2) > 0
        @serial_enabled = value & (0x1 << 3) > 0
        @joypad_enabled = value & (0x1 << 4) > 0
      else raise "Writing to invalid interrupts register: #{hex_str index.to_u16!}"
      end
    end
  end
end
