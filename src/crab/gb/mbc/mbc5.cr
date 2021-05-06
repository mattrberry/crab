module GB
  class MBC5 < Cartridge
    def initialize(@rom : Bytes)
      @ram = Bytes.new ram_size
      @ram_enabled = false
      @rom_bank_number = 1_u16 # 9-bit register
      @ram_bank_number = 0_u8  # 4-bit register
    end

    def [](index : Int) : UInt8
      case index
      when Memory::ROM_BANK_0
        @rom[index]
      when Memory::ROM_BANK_N
        @rom[rom_bank_offset(@rom_bank_number) + rom_offset(index)]
      when Memory::EXTERNAL_RAM
        @ram_enabled ? @ram[ram_bank_offset(@ram_bank_number) + ram_offset(index)] : 0xFF_u8
      else raise "Reading from invalid cartridge register #{hex_str index.to_u16!}"
      end
    end

    def []=(index : Int, value : UInt8) : Nil
      case index
      when 0x0000..0x1FFF # different than mbc1, now 8-bit register
        enabling = value & 0xFF == 0x0A
        save_game if @ram_enabled && !enabling
        @ram_enabled = enabling
      when 0x2000..0x2FFF # select lower 8 bits
        @rom_bank_number = (@rom_bank_number & 0x0100) | value
      when 0x3000..0x3FFF # select upper 1 bit
        @rom_bank_number = (@rom_bank_number & 0x00FF) | (value.to_u16 & 1) << 8
      when 0x4000..0x5FFF
        @ram_bank_number = value & 0b00001111
      when 0x6000..0x7FFF
        # unmapped write
      when Memory::EXTERNAL_RAM
        @ram[ram_bank_offset(@ram_bank_number) + ram_offset(index)] = value if @ram_enabled
      else raise "Writing to invalid cartridge register: #{hex_str index.to_u16!}"
      end
    end
  end
end
