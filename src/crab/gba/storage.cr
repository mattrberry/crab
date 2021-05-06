module GBA
  abstract class Storage
    enum Type
      EEPROM
      SRAM
      FLASH
      FLASH512
      FLASH1M

      def regex : Regex # don't rely on the 3 digits after this string
        /#{self}_V/
      end

      def bytes : Int
        case self
        in EEPROM   then abort "todo: Support EEPROM"
        in SRAM     then 0x08000
        in FLASH    then 0x10000
        in FLASH512 then 0x10000
        in FLASH1M  then 0x20000
        end
      end
    end

    @dirty = false
    setter save_path : String = ""
    getter memory : Bytes = Bytes.new 0 # implementing class needs to override

    def self.new(rom_path : String) : Storage
      save_path = rom_path.rpartition('.')[0] + ".sav"
      type = File.open(rom_path, "rb") { |file| find_type(file) }
      puts "Backup type could not be identified.".colorize.fore(:red) unless type
      puts "Backup type: #{type}, save path: #{save_path}"
      storage = case type
                in Type::EEPROM                               then abort "todo: Support EEPROM"
                in Type::SRAM, nil                            then SRAM.new
                in Type::FLASH, Type::FLASH512, Type::FLASH1M then Flash.new type
                end
      storage.save_path = save_path
      File.open(save_path, &.read(storage.memory)) if File.exists?(save_path)
      storage
    end

    def write_save : Nil
      if @dirty
        File.write(@save_path, @memory)
        @dirty = false
      end
    end

    abstract def [](index : Int) : Byte

    def read_half(index : Int) : HalfWord
      0x0101_u16 * self[index & ~1]
    end

    def read_word(index : Int) : Word
      0x01010101_u32 * self[index & ~3]
    end

    abstract def []=(index : Int, value : Byte) : Nil

    private def self.find_type(file : File) : Type?
      str = file.gets_to_end
      Type.each { |type| return type if type.regex.matches?(str) }
    end
  end
end
