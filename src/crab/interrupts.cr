class Interrupts
  getter reg_ie : UInt16 = 0
  getter reg_if : UInt16 = 0
  getter reg_ime : Bool = false

  def read_io(io_addr : Int) : Byte
    case io_addr
    when 0x200 then 0xFF_u8 & @reg_ie
    when 0x201 then 0xFF_u8 & @reg_ie >> 8
    when 0x202 then 0xFF_u8 & @reg_if
    when 0x203 then 0xFF_u8 & @reg_if >> 8
    when 0x208 then @reg_ime ? 1_u8 : 0_u8
    when 0x209 then @reg_ime ? 1_u8 : 0_u8
    else            raise "Unimplemented interrupts read ~ addr:#{hex_str io_addr.to_u8}"
    end
  end

  def write_io(io_addr : Int, value : Byte) : Nil
    case io_addr
    when 0x200 then @reg_ie = (@reg_ie & 0xFF00) | value
    when 0x201 then @reg_ie = (@reg_ie & 0x00FF) | value.to_u16 << 8
    when 0x202 then @reg_ie = (@reg_if & 0xFF00) | value
    when 0x203 then @reg_ie = (@reg_if & 0x00FF) | value.to_u16 << 8
    when 0x208 then @reg_ime = bit?(value, 0)
    when 0x209 then @reg_ime = bit?(value, 0)
    else            raise "Unimplemented interrupts write ~ addr:#{hex_str io_addr.to_u8!}, val:#{value}"
    end
  end
end
