module GB
  class Timer
    @div : UInt16 = 0x0000       # 16-bit divider register
    @tima : UInt8 = 0x00         # 8-bit timer register
    @tma : UInt8 = 0x00          # value to load when tima overflows
    @enabled : Bool = false      # if timer is enabled
    @clock_select : UInt8 = 0x00 # frequency flag determining when to increment tima
    @bit_for_tima = 9            # bit to detect falling edge for tima increments

    @previous_bit = false # used to detect falling edge
    @countdown = -1       # load tma and set interrupt flag when countdown is 0

    def initialize(@gb : GB)
    end

    def skip_boot : Nil
      @div = 0x2674_u16
    end

    # tick timer forward by specified number of cycles
    def tick(cycles : Int) : Nil
      cycles.times do
        @countdown -= 1 if @countdown > -1
        reload_tima if @countdown == 0
        @div &+= 1
        check_edge
      end
    end

    # read from timer memory
    def [](index : Int) : UInt8
      case index
      when 0xFF04 then (@div >> 8).to_u8
      when 0xFF05 then @tima
      when 0xFF06 then @tma
      when 0xFF07 then 0xF8_u8 | (@enabled ? 0b100 : 0) | @clock_select
      else             raise "Reading from invalid timer register: #{hex_str index.to_u16!}"
      end
    end

    # write to timer memory
    def []=(index : Int, value : UInt8) : Nil
      case index
      when 0xFF04
        @div = 0x0000_u16
        check_edge on_write: true
      when 0xFF05
        if @countdown != 0 # ignore writes on cycle that tma is loaded
          @tima = value
          @countdown = -1 # abort interrupt and tma load
        end
      when 0xFF06
        @tma = value
        @tima = @tma if @countdown == 0 # write to tima on cycle that tma is loaded
      when 0xFF07
        @enabled = value & 0b100 != 0
        @clock_select = value & 0b011
        @bit_for_tima = case @clock_select
                        when 0b00 then 9
                        when 0b01 then 3
                        when 0b10 then 5
                        when 0b11 then 7
                        else           raise "Selecting bit for TIMA. Will never be reached."
                        end
        check_edge on_write: true
      else raise "Writing to invalid timer register: #{hex_str index.to_u16!}"
      end
    end

    private def reload_tima : Nil
      @gb.interrupts.timer_interrupt = true
      @tima = @tma
    end

    # Check the falling edge in div counter
    # Note: reload and interrupt flag happen immediately on write
    #       This isn't actually entirely true. For more details on how this _actually_ works, read from gekkio
    #       starting here: https://discord.com/channels/465585922579103744/465586075830845475/793581987512188961
    private def check_edge(on_write = false) : Nil
      current_bit = @enabled && (@div & (1 << @bit_for_tima) != 0)
      if @previous_bit && !current_bit
        @tima &+= 1
        if @tima == 0
          if on_write
            reload_tima
          else
            @countdown = 4
          end
        end
      end
      @previous_bit = current_bit
    end
  end
end
