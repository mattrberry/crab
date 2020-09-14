def hex_str(n : UInt8 | UInt16 | UInt32 | UInt64) : String
  "0x#{n.to_s(16).rjust(sizeof(typeof(n)) * 2, '0').upcase}"
end

macro bit?(value, bit)
  ({{value}} & (1 << {{bit}}) > 0)
end

macro bits(value, range)
  ({{value}} >> ({{range}}).begin) & ((1 << ({{range}}).size) - 1)
end

macro set_bit(value, bit)
  ({{value}} | 1 << {{bit}})
end

macro clear_bit(value, bit)
  ({{value}} & ~(1 << {{bit}}))
end
