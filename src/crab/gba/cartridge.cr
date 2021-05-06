module GBA
  class Cartridge
    getter rom : Bytes

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
      # The following logic accounts for improperly dumped ROMs or bad homebrews.
      # All proper ROMs should have a power-of-two size. The handling here is
      # really pretty arbitrary. mGBA chooses to fill the entire ROM address
      # space with zeros in this case, although gba-suite/unsafe tests that there
      # are zeros up to the next power of two. I've chosen to just make that test
      # pass, although there's an argument to be made that it's better to match
      # mGBA behavior instead. Either way, if a ROM relies on this behavior, it's
      # a buggy ROM. This is just an attempt to match the some expected behavior.
      size = File.size(rom_path)
      if count_set_bits(size) != 1
        last_bit = last_set_bit(size)
        next_power = 2 ** (last_bit + 1)
        (size...next_power).each { |i| @rom[i] = 0 }
      end
    end
  end
end
