module GB
  abstract class Cartridge
    enum CGB
      EXCLUSIVE
      SUPPORT
      NONE
    end

    @rom : Bytes = Bytes.new 0
    @ram : Bytes = Bytes.new 0
    property sav_file_path : String = ""

    getter title : String {
      io = IO::Memory.new
      io.write @rom[0x0134...0x13F]
      io.to_s.gsub(/[^[:print:]]/i, "").strip
    }

    getter rom_size : UInt32 {
      0x8000_u32 << @rom[0x0148]
    }

    getter ram_size : Int32 {
      case @rom[0x0149]
      when 0x01 then 0x0800
      when 0x02 then 0x2000
      when 0x03 then 0x2000 << 2
      when 0x04 then 0x2000 << 4
      when 0x05 then 0x2000 << 3
      else           0x0000
      end
    }

    getter cgb : CGB {
      case @rom[0x0143]
      when 0x80 then CGB::SUPPORT
      when 0xC0 then CGB::EXCLUSIVE
      else           CGB::NONE
      end
    }

    # open rom, determine MBC type, and initialize the correct cartridge
    def self.new(rom_path : String) : Cartridge
      rom = File.open rom_path do |file|
        rom_size = file.read_at(0x0148, 1) { |io| 0x8000 << io.read_byte.not_nil! }
        file.pos = 0
        bytes = Bytes.new rom_size.not_nil!
        file.read bytes
        bytes
      end

      cartridge_type = rom[0x0147]
      cartridge = case cartridge_type
                  when 0x00, 0x08, 0x09 then ROM.new rom
                  when 0x01, 0x02, 0x03 then MBC1.new rom
                  when 0x05, 0x06       then MBC2.new rom
                  when 0x0F, 0x10, 0x11,
                       0x12, 0x13 then MBC3.new rom
                  when 0x19, 0x1A, 0x1B,
                       0x1C, 0x1D, 0x1E then MBC5.new rom
                  else raise "Unimplemented cartridge type: #{hex_str cartridge_type}"
                  end

      cartridge.sav_file_path = rom_path.rpartition('.')[0] + ".sav"
      cartridge.load_game if File.exists?(cartridge.sav_file_path)
      cartridge
    end

    # create a new Cartridge with the given bytes as rom
    def self.new(rom : Bytes) : Cartridge
      ROM.new rom
    end

    # save the game to a .sav file
    def save_game : Nil
      File.write(@sav_file_path.not_nil!, @ram)
    end

    # load the game from a .sav file
    def load_game : Nil
      File.open @sav_file_path do |file|
        file.read @ram
      end
    end

    # the offset of the given bank number in rom
    def rom_bank_offset(bank_number : Int) : Int
      (bank_number.to_u32 * Memory::ROM_BANK_N.size) % rom_size
    end

    # adjust the index for local rom
    def rom_offset(index : Int) : Int
      index - Memory::ROM_BANK_N.begin
    end

    # the offset of the given bank number in ram
    def ram_bank_offset(bank_number : Int) : Int
      (bank_number.to_u32 * Memory::EXTERNAL_RAM.size) % ram_size
    end

    # adjust the index for local ram
    def ram_offset(index : Int) : Int
      index - Memory::EXTERNAL_RAM.begin
    end

    # read from cartridge memory
    abstract def [](index : Int) : UInt8
    abstract def []=(index : Int, value : UInt8) : Nil
  end
end
