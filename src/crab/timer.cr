class Timer
  class TMCNT < BitField(UInt16)
    num not_used_1, 8, lock: true
    bool enable
    bool irq_enable
    num not_used_2, 3, lock: true
    bool cascade
    num frequency, 2

    def to_s(io)
      io << "TMCNT(enable:#{enable},irq:#{irq_enable},cascade:#{cascade},freq:#{frequency}"
    end
  end

  @interrupt_events : Array(Proc(Nil))

  def initialize(@gba : GBA)
    @tmcnt = Array(TMCNT).new 4 { TMCNT.new 0 }
    @tmd = Array(UInt16).new 4, 0                       # reload values
    @tm = Array(UInt16).new 4, 0                        # counted values
    @cycle_enabled = Array(UInt64).new 4, 0             # cycle that the timer was enabled
    @events = Array(Proc(Nil)).new 4 { |i| overflow i } # overflow closures for each timer
    @event_types = [Scheduler::EventType::Timer0, Scheduler::EventType::Timer1, Scheduler::EventType::Timer2, Scheduler::EventType::Timer3]
    @interrupt_events = [->{ @gba.interrupts.reg_if.timer0 = true }, ->{ @gba.interrupts.reg_if.timer1 = true },
                         ->{ @gba.interrupts.reg_if.timer2 = true }, ->{ @gba.interrupts.reg_if.timer3 = true }]
  end

  def overflow(timer_number : Int) : Proc(Nil)
    tmcnt = @tmcnt[timer_number]
    ->{
      puts "overflowed timer #{timer_number}".colorize.fore(:green)
      @tm[timer_number] = @tmd[timer_number]
      if timer_number < 3
        next_timer_number = timer_number + 1
        if @tmcnt[next_timer_number].cascade && @tmcnt[next_timer_number].enable
          @tm[next_timer_number] &+= 1
          @events[next_timer_number].call if @tm[next_timer_number] == 0 # tell the next timer that it has overflowed
        end
      end
      @interrupt_events[timer_number].call
      @gba.interrupts.schedule_interrupt_check if tmcnt.irq_enable
      cycles_until_overflow = freq_to_cycles(tmcnt.frequency) * (0xFFFF - @tm[timer_number])
      puts "  scheduling overflow for timer #{timer_number} in #{cycles_until_overflow} cycles" unless tmcnt.cascade
      @gba.scheduler.schedule cycles_until_overflow, @events[timer_number], @event_types[timer_number] unless tmcnt.cascade
    }
  end

  def read_io(io_addr : Int) : UInt8
    timer_number = (io_addr & 0xFF) // 4
    timer_control = bit?(io_addr, 1)
    high = bit?(io_addr, 0)
    tmcnt = @tmcnt[timer_number]
    value = if timer_control
              tmcnt.value
            else
              elapsed = @gba.scheduler.cycles - @cycle_enabled[timer_number]
              @tm[timer_number] &+= elapsed // freq_to_cycles(tmcnt.frequency) if tmcnt.enable && !tmcnt.cascade
              @tm[timer_number]
            end
    value >>= 8 if high
    value.to_u8!
  end

  def write_io(io_addr : Int, value : UInt8) : Nil
    timer_number = (io_addr & 0xFF) // 4
    timer_control = bit?(io_addr, 1)
    puts "io_addr: #{hex_str io_addr.to_u16}, value: #{hex_str value}, timer number: #{timer_number}, timer_control: #{timer_control}"
    high = bit?(io_addr, 0)
    mask = 0xFF_u16
    mask <<= 8 unless high
    value = value.to_u16 << 8 if high
    if timer_control
      # todo: properly handle disabling / enabling timers via `cascade` field
      tmcnt = @tmcnt[timer_number]
      puts "  updating TM#{timer_number}CNT from #{hex_str tmcnt.value} to #{hex_str (tmcnt.value & mask) | value}"
      puts "  #{tmcnt.to_s}"
      enabled = tmcnt.enable
      tmcnt.value = (tmcnt.value & mask) | value
      if tmcnt.enable && !enabled # enabled
        puts "  enabling".colorize.mode(:bold)
        @cycle_enabled[timer_number] = @gba.scheduler.cycles
        @tm[timer_number] = @tmd[timer_number]
        puts "  freq_to_cycles(#{tmcnt.frequency}) -> #{hex_str freq_to_cycles(tmcnt.frequency)}, @tm[#{timer_number}] -> #{hex_str @tm[timer_number]}, 0xFFFF - @tm[#{timer_number}] -> #{0xFFFF - @tm[timer_number]}"
        cycles_until_overflow = freq_to_cycles(tmcnt.frequency) * (0xFFFF - @tm[timer_number])
        puts "  scheduling overflow for timer #{timer_number} in #{cycles_until_overflow} cycles"
        @gba.scheduler.schedule cycles_until_overflow, @events[timer_number], @event_types[timer_number] unless tmcnt.cascade
      elsif !tmcnt.enable && enabled # disabled
        puts "  disabling".colorize.mode(:bold)
        elapsed = @gba.scheduler.cycles - @cycle_enabled[timer_number]
        @tm[timer_number] &+= elapsed // freq_to_cycles(tmcnt.frequency)
        @gba.scheduler.clear @event_types[timer_number]
      end
    else
      tmd = @tmd[timer_number]
      puts "  updating TM#{timer_number}D from #{hex_str tmd} to #{hex_str (tmd & mask) | value}"
      @tmd[timer_number] = (tmd & mask) | value
    end
  end

  def freq_to_cycles(freq : Int) : Int
    case freq
    when 0 then 0b1_u32
    else        0b10000_u32 << (freq << 1)
    end
  end
end
