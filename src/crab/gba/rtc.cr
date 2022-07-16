module GBA
  class RTC
    @sck : Bool = false
    @sio : Bool = false
    @cs : Bool = false

    @state : State = State::WAITING
    @reg : Register = Register::CONTROL
    @buffer = Buffer.new

    # control reg
    @irq : Bool = false # irqs every 30s
    @m24 : Bool = true  # 24-hour mode
    # todo: how does the power off bit work?

    enum State
      WAITING # waiting to start accepting a command
      COMMAND # reading a command
      READING # reading from a register
      WRITING # writing to a register
    end

    enum Register
      RESET     = 0
      CONTROL   = 1
      DATE_TIME = 2
      TIME      = 3
      IRQ       = 6

      def bytes : Int
        case self
        when CONTROL   then 1
        when DATE_TIME then 7
        when TIME      then 3
        else                0
        end
      end
    end

    def initialize(@gba : GBA)
    end

    def read : UInt8
      @sck.to_unsafe.to_u8! | @sio.to_unsafe.to_u8! << 1 | @cs.to_unsafe.to_u8! << 2
    end

    def write(value : UInt8) : Nil
      sck = bit?(value, 0)
      sio = bit?(value, 1)
      cs = bit?(value, 2)

      case @state
      in State::WAITING
        if @sck && sck && !@cs && cs # cs rises
          @state = State::COMMAND
          @cs = true # cs stays high until command is complete
        end
        @sck = sck
        @sio = sio
      in State::COMMAND
        if !@sck && sck # sck rises
          @buffer.push sio
          if @buffer.size == 8 # commands are 8 bits wide
            @state, @reg = read_command(@buffer.shift_byte)
            if @state == State::READING
              prepare_read
            else
              execute_write if @reg.bytes == 0
            end
          end
        end
        @sck = sck
        @sio = sio
      in State::READING
        if !@sck && sck # sck rises
          @sio = @buffer.shift
          if @buffer.size == 0
            @state = State::WAITING
            @cs = false # command has finished
          end
        end
        @sck = sck
      in State::WRITING
        if !@sck && sck # sck rises
          @buffer.push sio
          execute_write if @buffer.size == @reg.bytes * 8
        end
        @sck = sck
        @sio = sio
      end
    end

    # Fill buffer with the data to read from the set register.
    private def prepare_read : Nil
      case @reg
      when Register::CONTROL
        control = 0b10_u8 | @irq.to_unsafe.to_u8! << 3 | @m24.to_unsafe.to_u8! << 6
        @buffer.push(control)
      when Register::DATE_TIME
        time = Time.local
        hour = time.hour
        hour %= 12 unless @m24
        @buffer.push bcd time.year % 100
        @buffer.push bcd time.month
        @buffer.push bcd time.day
        @buffer.push bcd time.day_of_week.value % 7
        @buffer.push bcd hour
        @buffer.push bcd time.minute
        @buffer.push bcd time.second
      when Register::TIME
        time = Time.local
        hour = time.hour
        hour %= 12 unless @m24
        @buffer.push bcd hour
        @buffer.push bcd time.minute
        @buffer.push bcd time.second
      end
    end

    # Execute a write to the set register.
    private def execute_write : Nil
      case @reg
      when Register::CONTROL
        byte = @buffer.shift_byte
        @irq = bit?(byte, 3)
        @m24 = bit?(byte, 6)
        puts "TODO: implement rtc irq" if @irq
      when Register::RESET
        @irq = false
        @m24 = false # todo: does this reset to 12hr or 24hr mode?
      when Register::IRQ
        @gba.interrupts.reg_if.game_pak = true
        @gba.interrupts.schedule_interrupt_check
      end
      @buffer.clear
      @state = State::WAITING
      @cs = false
    end

    # Read the given command, reversing if necessary.
    private def read_command(full_command : UInt8) : Tuple(State, Register)
      command_bits = 0xF_u8 & if full_command.bits(0..3) == 0b0110
        reverse_bits(full_command)
      else
        full_command
      end
      {bit?(command_bits, 0) ? State::READING : State::WRITING, Register.from_value(command_bits >> 1)}
    end

    # Reverse the bits in the given byte
    private def reverse_bits(byte : UInt8) : UInt8
      result = 0_u8
      (0..7).each do |bit|
        result |= 1 << bit if bit?(byte, 7 - bit)
      end
      result
    end

    # Convert the given number to binary-coded decimal. Expects numbers less
    # than 100. Result is undefined otherwise.
    private def bcd(int : Int) : UInt8
      ((int.to_u8! // 10) << 4) | (int.to_u8! % 10)
    end

    # FIFO bit buffer implementation.
    # todo: This impl is similar to what's used in eeprom.cr. Maybe merge.
    private class Buffer
      property size = 0
      property value : UInt64 = 0

      def push(value : Bool) : Nil
        @size += 1
        @value = (@value << 1) | (value.to_unsafe & 1)
      end

      # push a byte in increasing significance
      def push(byte : UInt8) : Nil
        (0..7).each do |bit|
          push(bit?(byte, bit))
        end
      end

      def shift : Bool
        abort "Invalid buffer size #{@size}" if @size <= 0
        @size -= 1
        @value >> @size & 1 == 1
      end

      # shift a byte, reading bits in increasing significance
      def shift_byte : UInt8
        result = 0_u8
        8.times do |bit|
          result |= 1 << bit if shift
        end
        result
      end

      def clear : Nil
        @size = 0
        @value = 0
      end
    end
  end
end
