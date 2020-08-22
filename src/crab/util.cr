def hex_str(n : UInt8 | UInt16 | UInt32 | UInt64) : String
  "0x#{n.to_s(16).rjust(sizeof(typeof(n)) * 2, '0').upcase}"
end

def bit?(value : Int, bit : Int) : Bool
  (value >> bit) & 1 > 0
end

def set_bit(value : Int, bit : Int) : Nil
  value | 1 << bit
end

def clear_bit(value : Int, bit : Int) : Nil
  value & ~(1 << bit)
end
