module GB
  class MBC3 < Cartridge
    def initialize(@rom : Bytes, @cartridge_type : CartridgeType)
      @ram = Bytes.new ram_size
      @ram_enabled = false
      @rom_bank_number = 1_u8 # 7-bit register
      @ram_bank_number = 0_u8 # 4-bit register
    end

    def [](index : Int) : UInt8
      case index
      when Memory::ROM_BANK_0
        @rom[index]
      when Memory::ROM_BANK_N
        @rom[rom_bank_offset(@rom_bank_number) + rom_offset(index)]
      when Memory::EXTERNAL_RAM
        if @ram_bank_number <= 3
          @ram_enabled ? @ram[ram_bank_offset(@ram_bank_number) + ram_offset(index)] : 0xFF_u8
        elsif @ram_bank_number <= 0x0C
          # puts "reading clock: #{hex_str @ram_bank_number}"
          0xFF_u8
        else
          raise "Invalid RAM/RTC bank register read: #{hex_str @ram_bank_number}"
        end
      else raise "Reading from invalid cartridge register #{hex_str index.to_u16!}"
      end
    end

    def []=(index : Int, value : UInt8) : Nil
      case index
      when 0x0000..0x1FFF
        enabling = value & 0x0F == 0x0A
        save_game if @ram_enabled && !enabling
        @ram_enabled = enabling
      when 0x2000..0x3FFF
        @rom_bank_number = value & 0x7F
        @rom_bank_number += 1 if @rom_bank_number == 0
      when 0x4000..0x5FFF
        @ram_bank_number = value
      when 0x6000..0x7FFF
        # puts "latch clock: #{hex_str value}"
      when Memory::EXTERNAL_RAM
        if @ram_bank_number <= 0x03
          @ram[ram_bank_offset(@ram_bank_number) + ram_offset(index)] = value if @ram_enabled
        elsif @ram_bank_number <= 0x0C
          # puts "writing to clock: #{hex_str @ram_bank_number} -> #{hex_str value}"
        else
          raise "Invalid RAM/RTC bank register write: #{hex_str @ram_bank_number}"
        end
      else raise "Writing to invalid cartridge register: #{hex_str index.to_u16!}"
      end
    end
  end
end
