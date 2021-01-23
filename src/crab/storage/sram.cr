class SRAM < Storage
  @memory = Bytes.new(Type::SRAM.bytes, 0x00)

  def [](index : Int) : Byte
    index < @memory.size ? @memory[index] : 0_u8
  end

  def []=(index : Int, value : Byte) : Nil
    if index < @memory.size
      @memory[index] = value
      @dirty = true
    end
  end
end
