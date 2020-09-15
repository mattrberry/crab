def hex_str(n : UInt8 | UInt16 | UInt32 | UInt64, prefix = true) : String
  (prefix ? "0x" : "") + "#{n.to_s(16).rjust(sizeof(typeof(n)) * 2, '0').upcase}"
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

macro trace(value, newline = true)
  {% if flag? :trace %}
    {% if newline %}
      puts {{value}}
    {% else %}
      print {{value}}
    {% end %}
  {% end %}
end

macro log(value, newline = true)
  {% if flag?(:log) %}
    {% if newline %}
      puts {{value}}
    {% else %}
      print {{value}}
    {% end %}
  {% end %}
end
