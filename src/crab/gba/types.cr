module GBA
  alias Byte = UInt8
  alias HalfWord = UInt16
  alias Word = UInt32
  alias Words = Slice(UInt32)
  record BGR16, value : UInt16 do # xBBBBBGGGGGRRRRR
    # Create a new BGR16 struct with the given values. Trucates at 5 bits.
    def initialize(blue : Number, green : Number, red : Number)
      @value = (blue <= 0x1F ? blue.to_u16 : 0x1F_u16) << 10 |
               (green <= 0x1F ? green.to_u16 : 0x1F_u16) << 5 |
               (red <= 0x1F ? red.to_u16 : 0x1F_u16)
    end

    def blue : UInt16
      bits(value, 0xA..0xE)
    end

    def green : UInt16
      bits(value, 0x5..0x9)
    end

    def red : UInt16
      bits(value, 0x0..0x4)
    end

    def +(other : BGR16) : BGR16
      BGR16.new(blue + other.blue, green + other.green, red + other.red)
    end

    def -(other : BGR16) : BGR16
      BGR16.new(blue.to_i - other.blue, green.to_i - other.green, red.to_i - other.red)
    end

    def *(operand : Number) : BGR16
      BGR16.new(blue * operand, green * operand, red * operand)
    end
  end
end
