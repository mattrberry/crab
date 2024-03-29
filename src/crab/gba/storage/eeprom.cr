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

    enum Size
      EEPROM_4K
      EEPROM_64K

      def addr_bits : Int32
        case self
        in EEPROM_4K  then 6
        in EEPROM_64K then 14
        end
      end

      def file_size : Int32
        case self
        in EEPROM_4K  then 0x200
        in EEPROM_64K then 0x2000
        end
      end

      def self.from_file_size(size : Int?) : Size?
        if size && size > 0
          size > 0x200 ? EEPROM_64K : EEPROM_4K
        end
      end

      def self.from_dma_length(length : Int) : Size
        length <= 6 ? EEPROM_4K : EEPROM_64K
      end
    end

    # todo: many of these variables are repetitive. clean them up
    @size : Size?
    @memory = Bytes.new(0x2000, 0xFF)
    @state = State::READY
    @buffer = Buffer.new
    @address : UInt32 = 0
    @ignored_reads = 0
    @read_bits = 0
    @wrote_bits = 0

    def initialize(@gba : GBA, file_size : Int64?)
      set_size(Size.from_file_size(file_size))
    end

    private def set_size(size : Size?) : Nil
      if size
        @size = size
        @memory = Bytes.new(size.file_size, 0xFF)
      end
    end

    def [](address : UInt32) : UInt8
      case @state
      when .includes? State::READ_IGNORE
        if (@ignored_reads += 1) == 4
          @state ^= State::READ_IGNORE
          @read_bits = 0
        end
      when State::READ
        value = @memory[@address * 8 + (@read_bits // 8)] >> (7 - @read_bits & 7) & 1
        @read_bits += 1
        if @read_bits == 64
          @state = State::READY
          @buffer.clear
          @read_bits = 0
        end
        return value
      end
      1_u8
    end

    def []=(address : UInt32, value : UInt8) : Nil
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
        set_size(Size.from_dma_length(@gba.dma.dmacnt_l[3])) unless @size
        if @buffer.size == @size.not_nil!.addr_bits
          @address = @buffer.value.to_u32! & 0x3FF
          @memory.to_unsafe.as(UInt64*)[@address] = 0 if @state.includes? State::WRITE
          @state ^= State::ADDRESS
          @buffer.clear
        end
      when .includes? State::WRITE
        idx = @wrote_bits // 8
        bit = 7 - (@wrote_bits & 7)
        cur = @memory[@address * 8 + idx]
        mask = 1 << bit
        @memory[@address * 8 + idx] = (cur & ~mask) | (value << bit)
        @dirty = true
        @wrote_bits += 1
        if @wrote_bits == 64
          @buffer.clear
          @wrote_bits = 0
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

    def shift : UInt64
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
