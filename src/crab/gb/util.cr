module GB
  def hex_str(n : UInt8 | UInt16 | UInt32 | UInt64) : String
    "0x#{n.to_s(16).rjust(sizeof(typeof(n)) * 2, '0').upcase}"
  end

  def array_to_uint8(array : Array(Bool | Int)) : UInt8
    raise "Array needs to have a length of 8" if array.size != 8
    value = 0_u8
    array.each_with_index do |bit, index|
      value |= (bit == false || bit == 0 ? 0 : 1) << (7 - index)
    end
    value
  end

  def array_to_uint16(array : Array(Bool | Int)) : UInt16
    raise "Array needs to have a length of 16" if array.size != 16
    value = 0_u16
    array.each_with_index do |bit, index|
      value |= (bit == false || bit == 0 ? 0 : 1) << (15 - index)
    end
    value
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
    {% if flag? :log %}
      {% if newline %}
        puts {{value}}
      {% else %}
        print {{value}}
      {% end %}
    {% end %}
  end
end
