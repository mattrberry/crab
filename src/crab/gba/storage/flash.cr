module GBA
  class Flash < Storage
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

    @state = State::READY
    @bank = 0_u8

    def initialize(@type : Type)
      @memory = Bytes.new(@type.bytes, 0xFF)
      @id = case @type
            when Type::FLASH1M then 0x1362 # Sanyo
            else                    0x1B32 # Panasonic
            end
    end

    def [](index : Int) : Byte
      index &= 0xFFFF
      if @state.includes?(State::IDENTIFICATION) && 0 <= index <= 1
        (@id >> (8 * index) & 0xFF).to_u8!
      else
        @memory[0x10000 * @bank + index]
      end
    end

    def []=(index : Int, value : Byte) : Nil
      index &= 0xFFFF
      case @state
      when .includes? State::PREPARE_WRITE
        @memory[0x10000 * @bank + index] &= value
        @dirty = true
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
          case Command.new(value)
          when Command::ENTER_IDENT   then @state |= State::IDENTIFICATION
          when Command::EXIT_IDENT    then @state ^= State::IDENTIFICATION
          when Command::PREPARE_ERASE then @state |= State::PREPARE_ERASE
          when Command::ERASE_ALL
            if @state.includes? State::PREPARE_ERASE
              @memory.size.times { |i| @memory[i] = 0xFF }
              @dirty = true
              @state ^= State::PREPARE_ERASE
            end
          when Command::PREPARE_WRITE then @state |= State::PREPARE_WRITE
          when Command::SET_BANK      then @state |= State::SET_BANK if @type == Type::FLASH1M
          else                             puts "Unsupported flash command #{hex_str value}"
          end
        elsif @state.includes?(State::PREPARE_ERASE) && index & 0x0FFF == 0 && value == Command::ERASE_CHUNK.value
          0x1000.times { |i| @memory[0x10000 * @bank + index + i] = 0xFF }
          @dirty = true
          @state ^= State::PREPARE_ERASE
        end
        @state ^= State::CMD_2
        @state |= State::READY
      end
    end
  end
end
