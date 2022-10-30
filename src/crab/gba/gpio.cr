require "./rtc"

module GBA
  class GPIO
    @data : UInt8 = 0x00
    @direction : UInt8 = 0x00
    getter allow_reads : Bool = false

    def initialize(@gba : GBA)
      @rtc = RTC.new(@gba) # todo: support other forms of gpio
    end

    def [](io_addr : UInt32) : UInt8
      case io_addr & 0xFF
      when 0xC4 # IO Port Data
        if @allow_reads
          (@data & ~@direction) & 0xF_u8
          @rtc.read & 0xF_u8
        else
          0_u8
        end
      when 0xC6 # IO Port Direction
        @direction & 0xF_u8
      when 0xC8 # IO Port Control
        @allow_reads ? 1_u8 : 0_u8
      else 0_u8
      end
    end

    def []=(io_addr : UInt32, value : UInt8) : Nil
      case io_addr & 0xFF
      when 0xC4 # IO Port Data
        @data &= value & 0xF_u8
        @rtc.write(value & 0xF_u8)
      when 0xC6 # IO Port Direction
        @direction = value & 0x0F
      when 0xC8 # IO Port Control
        @allow_reads = bit?(value, 0)
      end
    end

    def address?(address : Int) : Bool
      (0x080000C4..0x080000C9).includes?(address)
    end
  end
end
