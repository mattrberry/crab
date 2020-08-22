class Cartridge
  @rom : Bytes

  getter title : String {
    io = IO::Memory.new
    io.write @rom[0x0A0...0x0AC]
    io.to_s
  }

  def initialize(rom_path : String)
    @rom = File.open rom_path do |file|
      bytes = Bytes.new file.size
      file.read bytes
      bytes
    end
  end

  def [](index : Int) : Byte
    @rom[index]
  end

  def []=(index : Int, value : Byte) : Nil
  end
end
