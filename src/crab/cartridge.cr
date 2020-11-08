class Cartridge
  @rom : Bytes

  getter title : String {
    io = IO::Memory.new
    io.write @rom[0x0A0...0x0AC]
    io.to_s
  }

  @rom = Bytes.new 0x02000000 do |addr|
    oob = 0xFFFF & (addr >> 1)
    (oob >> (8 * (addr & 1))).to_u8!
  end

  def initialize(rom_path : String)
    File.open(rom_path) { |file| file.read @rom }
  end

  def [](index : Int) : Byte
    @rom[index]
  end
end
