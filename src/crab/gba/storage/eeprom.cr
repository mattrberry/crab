module GBA
  class EEPROM < Storage
    @[Flags]
    enum State
      READY
      READ
      READ_IGNORE
      WRITE
      ADDRESS
      WRITE_FINAL_BIT

      LOCK_ADDRESS

      CMD_1
      CMD_2
      IDENTIFICATION
      PREPARE_WRITE
      PREPARE_ERASE
      SET_BANK
    end

    @memory = Bytes.new(0x2000, 0xFF)
    @state = State::READY
    @buffer = Buffer.new
    @address : UInt32 = 0
    @ignored_reads = 0

    def [](index : Int) : Byte
      case @state
      when .includes? State::READ_IGNORE
        if (@ignored_reads += 1) == 4
          @state ^= State::READ_IGNORE
          @buffer.value = @memory.to_unsafe.as(UInt64*)[@address]
          @buffer.size = 64
        end
      when State::READ
        value = @buffer.pop.to_u8
        if @buffer.size == 0
          @state = State::READY
          @buffer.clear
        end
        return value
      end
      1_u8
    end

    def []=(index : Int, value : Byte) : Nil
      return if @state == State::READ || @state == State::READ_IGNORE
      value &= 1
      @buffer.push value
      case @state
      when State::READY
        if @buffer.size == 2
          case @buffer.value
          when 0b10 then @state = State::ADDRESS | State::WRITE | State::WRITE_FINAL_BIT
          when 0b11 then @state = State::ADDRESS | State::READ | State::READ_IGNORE | State::WRITE_FINAL_BIT; @ignored_reads = 0
          end
          @address = 0
          @buffer.clear
        end
      when .includes? State::ADDRESS
        if @buffer.size == 14 # todo: support 4Kbit eeprom
          @address = @buffer.value.to_u32
          @memory.to_unsafe.as(UInt64*)[@address] = 0 if @state.includes? State::WRITE
          @state ^= State::ADDRESS
          @buffer.clear
        end
      when .includes? State::WRITE
        index = (@buffer.size - 1) // 8
        if @buffer.size == 64
          @memory.to_unsafe.as(UInt64*)[@address] = @buffer.value
          @buffer.clear
          @state = State::READY | State::WRITE_FINAL_BIT
        end
      when .includes? State::WRITE_FINAL_BIT
        @buffer.clear
        @state ^= State::WRITE_FINAL_BIT
      end
    end
  end

  private class Buffer
    property size = 0
    property value : UInt64 = 0

    def push(value : Int) : UInt64
      @size += 1
      @value = (@value << 1) | (value & 1)
    end

    def pop : UInt64
      abort "Invalid buffer size #{@size}" if @size <= 0
      @size -= 1
      @value >> @size & 1
    end

    def clear : Nil
      @size = 0
      @value = 0
    end
  end
end
