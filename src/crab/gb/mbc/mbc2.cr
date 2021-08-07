module GB
  class MBC2 < Cartridge
    getter ram_size : Int32 { 0x0200 }

    def initialize(@rom : Bytes, @cartridge_type : CartridgeType)
      @ram = Bytes.new ram_size
      @ram_enabled = false
      @rom_bank = 1_u8
    end

    def [](index : Int) : UInt8
      case index
      when Memory::ROM_BANK_0
        @rom[index]
      when Memory::ROM_BANK_N
        @rom[rom_bank_offset(@rom_bank) + rom_offset(index)]
      when Memory::EXTERNAL_RAM
        if @ram_enabled
          @ram[ram_offset(index) % ram_size] | 0xF0
        else
          0xFF_u8
        end
      else raise "Reading from invalid cartridge register #{hex_str index.to_u16!}"
      end
    end

    def []=(index : Int, value : UInt8) : Nil
      case index
      when 0x0000..0x3FFF
        if index & 0x0100 == 0 # RAMG
          enabling = value & 0x0F == 0b1010
          save_game if @ram_enabled && !enabling
          @ram_enabled = enabling
        else # ROMB
          @rom_bank = value & 0x0F
          @rom_bank += 1 if @rom_bank == 0
        end
      when Memory::EXTERNAL_RAM
        if @ram_enabled
          @ram[ram_offset(index) % ram_size] = value & 0x0F
        end
      end
    end
  end
end
