module GB
  class MBC1 < Cartridge
    def initialize(@rom : Bytes, @cartridge_type : CartridgeType)
      if ram_size == 0 && (@rom[0x0147] == 0x02 || @rom[0x0147] == 0x03)
        STDERR.puts "MBC1 cartridge has ram, but `ram_size` was reported as 0. Ignoring `ram_size` and using 8kB of ram."
        @ram = Bytes.new 0x2000
      else
        @ram = Bytes.new ram_size
      end
      @ram_enabled = false
      @mode = 0_u8
      @reg1 = 1_u8 # main rom banking register
      @reg2 = 0_u8 # secondary banking register
    end

    def [](index : Int) : UInt8
      case index
      when Memory::ROM_BANK_0
        if @mode == 0
          @rom[index]
        else
          # can contain banks 20/40/60 in mode 1
          bank_number = (@reg2 << 5)
          @rom[rom_bank_offset(bank_number) + index]
        end
      when Memory::ROM_BANK_N
        bank_number = ((@reg2 << 5) | @reg1)
        @rom[rom_bank_offset(bank_number) + rom_offset(index)]
      when Memory::EXTERNAL_RAM
        if @ram_enabled && @ram.size > 0
          if @mode == 0
            @ram[ram_offset index]
          else
            @ram[ram_bank_offset(@reg2) + ram_offset(index)]
          end
        else
          0xFF_u8
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
        @reg1 = value & 0b00011111 # select 5 bits
        @reg1 += 1 if @reg1 == 0   # translate 0 to 1
      when 0x4000..0x5FFF
        @reg2 = value & 0b00000011 # select 2 bits
      when 0x6000..0x7FFF
        @mode = value & 0x1
      when Memory::EXTERNAL_RAM
        if @ram_enabled && @ram.size > 0
          if @mode == 0
            @ram[ram_offset index] = value
          else
            @ram[ram_bank_offset(@reg2) + ram_offset(index)] = value
          end
        end
      else raise "Writing to invalid cartridge register: #{hex_str index.to_u16!}"
      end
    end
  end
end
