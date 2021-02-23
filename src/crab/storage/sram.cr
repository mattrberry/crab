class SRAM < Storage
  @memory = Bytes.new(Type::SRAM.bytes, 0xFF)

  def [](index : Int) : Byte
    @memory[index & 0x7FFF]
  end

  def []=(index : Int, value : Byte) : Nil
    @memory[index & 0x7FFF] = value
    @dirty = true
  end
end
