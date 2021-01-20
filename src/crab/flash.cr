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

  enum State
    READY
    CMD_1
    CMD_2
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
  @sram = Bytes.new 0x10000, 0xFF
  @state = State::READY
  @identification_mode = false

  def initialize(rom_path : String)
    File.open(rom_path, "rb") do |file|
      str = file.gets_to_end
      Type.each do |type|
        if type.regex.matches?(str)
          @type = type
          break
        end
      end
    end
    unless @type
      puts "Falling back to SRAM since backup type could not be identified.".colorize.fore(:red)
      @type = Type::SRAM
    end
    puts "Backup type: #{@type}"
    @save_path = rom_path.gsub(/\.gba$/, ".sav")
    @save_path += ".sav" unless @save_path.ends_with?(".sav")
    puts "Save path: #{@save_path}"
  end

  def [](index : Int) : Byte
    puts "#{hex_str index.to_u16}"
    if @identification_mode && 0 <= index <= 1
      (SANYO >> (8 * index) & 0xFF).to_u8!
    else
      @sram[index]
    end
  end

  def []=(index : Int, value : Byte) : Nil
    puts "#{hex_str index.to_u16} -> #{hex_str value}        #{@state}"
    case @state
    in State::READY
      @state = State::CMD_1 if value == 0xAA
    in State::CMD_1
      @state = State::CMD_2 if value == 0x55
    in State::CMD_2
      case value
      when Command::ENTER_IDENT.value then @identification_mode = true
      when Command::EXIT_IDENT.value  then @identification_mode = false
      when Command::PREPARE_ERASE.value
      when Command::ERASE_ALL.value
      when Command::ERASE_CHUNK.value
      when Command::PREPARE_WRITE.value
      when Command::SET_BANK.value
      else puts "Unsupported command #{hex_str value}"
      end
    end
    puts "  #{@state}"
    @sram[index] = value
  end
end
