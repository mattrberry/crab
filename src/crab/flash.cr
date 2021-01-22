class Flash
  enum Type
    EEPROM
    SRAM
    FLASH
    FLASH512
    FLASH1M

    def regex : Regex
      /#{self}_V\d{3}/
    end
  end

  @[Flags]
  enum State
    READY
    CMD_1
    CMD_2
    IDENTIFICATION
    PREPARE_WRITE
    PREPARE_ERASE
    SET_BANK
  end

  enum Command : Byte
    ENTER_IDENT   = 0x90
    EXIT_IDENT    = 0xF0
    PREPARE_ERASE = 0x80
    ERASE_ALL     = 0x10
    ERASE_CHUNK   = 0x30
    PREPARE_WRITE = 0xA0
    SET_BANK      = 0xB0
  end

  SANYO = 0x1362_u16

  getter! type : Type
  @save_path : String
  @memory = Bytes.new 0x20000, 0xFF
  @bank = 0_u8
  @state = State::READY

  @identification_mode = false
  @prepare_write = false

  def initialize(rom_path : String)
    @type = File.open(rom_path, "rb") { |file| find_type(file) }
    unless @type
      puts "Falling back to SRAM since backup type could not be identified.".colorize.fore(:red)
      @type = Type::SRAM
    end
    puts "Backup type: #{@type}"
    @save_path = rom_path.gsub(/\.gba$/, ".sav")
    @save_path += ".sav" unless @save_path.ends_with?(".sav")
    puts "Save path: #{@save_path}"
    if File.exists?(@save_path)
      File.open(@save_path) { |file| file.read @memory }
    else
      File.write(@save_path, @memory)
    end
  end

  def [](index : Int) : Byte
    if @state.includes?(State::IDENTIFICATION) && 0 <= index <= 1
      (SANYO >> (8 * index) & 0xFF).to_u8!
    else
      @memory[0x10000 * @bank + index]
    end
  end

  def []=(index : Int, value : Byte) : Nil
    case @state
    when .includes? State::PREPARE_WRITE
      @memory[0x10000 * @bank + index] &= value
      File.write(@save_path, @memory)
      @state ^= State::PREPARE_WRITE
    when .includes? State::SET_BANK
      @bank = value & 1
      @state ^= State::SET_BANK
    when .includes? State::READY
      if index == 0x5555 && value == 0xAA
        @state ^= State::READY
        @state |= State::CMD_1
      end
    when .includes? State::CMD_1
      if index == 0x2AAA && value == 0x55
        @state ^= State::CMD_1
        @state |= State::CMD_2
      end
    when .includes? State::CMD_2
      if index == 0x5555
        case value
        when Command::ENTER_IDENT.value   then @state |= State::IDENTIFICATION
        when Command::EXIT_IDENT.value    then @state ^= State::IDENTIFICATION
        when Command::PREPARE_ERASE.value then @state |= State::PREPARE_ERASE
        when Command::ERASE_ALL.value
          if @state.includes? State::PREPARE_ERASE
            @memory.size.times { |i| @memory[i] = 0xFF }
            File.write(@save_path, @memory)
            @state ^= State::PREPARE_ERASE
          end
        when Command::PREPARE_WRITE.value then @state |= State::PREPARE_WRITE
        when Command::SET_BANK.value      then @state |= State::SET_BANK
        else                                   puts "Unsupported flash command #{hex_str value}"
        end
      elsif @state.includes?(State::PREPARE_ERASE) && index & 0x0FFF == 0 && value == Command::ERASE_CHUNK.value
        0x1000.times { |i| @memory[0x10000 * @bank + index + i] = 0xFF }
        File.write(@save_path, @memory)
        @state ^= State::PREPARE_ERASE
      end
      @state ^= State::CMD_2
      @state |= State::READY
    end
  end

  private def find_type(file : File) : Type?
    str = file.gets_to_end
    Type.each { |type| return type if type.regex.matches?(str) }
  end
end
