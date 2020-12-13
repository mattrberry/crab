class DMAChannels
  RANGE = 0xA0..0xA7

  def ===(value) : Bool
    value.is_a?(Int) && RANGE.includes?(value)
  end

  def initialize(@gba : GBA)
  end

  def read_io(index : Int) : UInt8
    abort "Reading DMA sound: #{hex_str index.to_u8}"
    0_u8
  end

  def write_io(index : Int, value : UInt8) : Nil
    abort "Writing DMA sound: #{hex_str index.to_u8} -> #{hex_str value}"
  end
end
