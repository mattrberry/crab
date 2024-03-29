def hex_str(n : UInt8 | UInt16 | UInt32 | UInt64, prefix = true) : String
  (prefix ? "0x" : "") + "#{n.to_s(16).rjust(sizeof(typeof(n)) * 2, '0').upcase}"
end

macro bit?(value, bit)
  ({{value}} & (1 << {{bit}}) > 0)
end

macro bits(value, range)
  ({{value}} >> {{range.begin}} & (1 << {{range.to_a.size}}) - 1)
end

macro set_bit(value, bit)
  ({{value}} | 1 << {{bit}})
end

macro set_bit(value, bit, set)
  (clear_bit({{value}}, {{bit}}) | {{set}} << {{bit}})
end

macro clear_bit(value, bit)
  ({{value}} & ~(1 << {{bit}}))
end

macro count_bits(value)
  (8 * sizeof(typeof(n)))
end

def count_set_bits(n : Int) : Int
  count = 0
  count_bits(n).times { |idx| count += n >> idx & 1 }
  count
end

def first_set_bit(n : Int) : Int
  count = count_bits(n)
  count.times { |idx| return idx if bit?(n, idx) }
  count
end

def last_set_bit(n : Int) : Int
  count = count_bits(n)
  count.downto(0) { |idx| return idx if bit?(n, idx) }
  count
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
