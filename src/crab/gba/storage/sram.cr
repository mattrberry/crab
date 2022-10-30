module GBA
  class SRAM < Storage
    @memory = Bytes.new(Type::SRAM.bytes, 0xFF)

    def [](address : UInt32) : UInt8
      @memory[address & 0x7FFF]
    end

    def []=(address : UInt32, value : UInt8) : Nil
      @memory[address & 0x7FFF] = value
      @dirty = true
    end
  end
end
