module GBA
  class Timer
    PERIODS     = [1, 64, 256, 1024]
    EVENT_TYPES = [Scheduler::EventType::Timer0, Scheduler::EventType::Timer1,
                   Scheduler::EventType::Timer2, Scheduler::EventType::Timer3]

    @interrupt_flags : Array(Proc(Nil))

    def initialize(@gba : GBA)
      @tmcnt = Array(Reg::TMCNT).new 4 { Reg::TMCNT.new 0 } # control registers
      @tmd = Array(UInt16).new 4, 0                         # reload values
      @tm = Array(UInt16).new 4, 0                          # counted values
      @cycle_enabled = Array(UInt64).new 4, 0               # cycle that the timer was enabled
      @events = Array(Proc(Nil)).new 4 { |i| overflow i }   # overflow closures for each timer
      @interrupt_flags = [->{ @gba.interrupts.reg_if.timer0 = true }, ->{ @gba.interrupts.reg_if.timer1 = true },
                          ->{ @gba.interrupts.reg_if.timer2 = true }, ->{ @gba.interrupts.reg_if.timer3 = true }]
    end

    def overflow(num : Int) : Proc(Nil)
      ->{
        @tm[num] = @tmd[num]
        @cycle_enabled[num] = @gba.scheduler.cycles
        if num < 3 && @tmcnt[num + 1].cascade && @tmcnt[num + 1].enable
          @tm[num + 1] &+= 1
          @events[num + 1].call if @tm[num + 1] == 0 # call overflow handler if cascaded timer overflowed
        end
        @gba.apu.timer_overflow num if num <= 1 # alert apu of timer 0-1 overflow
        if @tmcnt[num].irq_enable               # set interupt flag for this timer
          @interrupt_flags[num].call
          @gba.interrupts.schedule_interrupt_check
        end
        @gba.scheduler.schedule cycles_until_overflow(num), @events[num], EVENT_TYPES[num] unless @tmcnt[num].cascade
      }
    end

    def cycles_until_overflow(num : Int) : Int32
      PERIODS[@tmcnt[num].frequency] * (0x10000 - @tm[num])
    end

    def get_current_tm(num : Int) : UInt16
      if @tmcnt[num].enable && !@tmcnt[num].cascade
        elapsed = @gba.scheduler.cycles - @cycle_enabled[num]
        @tm[num] &+ elapsed // PERIODS[@tmcnt[num].frequency]
      else
        @tm[num]
      end
    end

    def update_tm(num : Int) : Nil
      @tm[num] = get_current_tm(num)
      @cycle_enabled[num] = @gba.scheduler.cycles
    end

    def read_io(io_addr : Int) : UInt8
      num = (io_addr & 0xF) // 4
      value = if bit?(io_addr, 1)
                @tmcnt[num].value
              else
                get_current_tm(num)
              end
      value >>= 8 if bit?(io_addr, 0)
      value.to_u8!
    end

    def write_io(io_addr : Int, value : UInt8) : Nil
      num = (io_addr & 0xF) // 4
      high = bit?(io_addr, 0)
      mask = 0xFF00_u16
      if high
        mask >>= 8
        value = value.to_u16 << 8
      end
      if bit?(io_addr, 1)
        unless high
          update_tm(num)
          tmcnt = @tmcnt[num]
          was_enabled = tmcnt.enable
          was_cascade = tmcnt.cascade
          tmcnt.value = (tmcnt.value & mask) | value
          if tmcnt.enable
            if tmcnt.cascade
              @gba.scheduler.clear EVENT_TYPES[num]
            elsif !was_enabled || was_cascade # enabled or no longer cascade
              @cycle_enabled[num] = @gba.scheduler.cycles
              @tm[num] = @tmd[num] if !was_enabled
              @gba.scheduler.schedule cycles_until_overflow(num), @events[num], EVENT_TYPES[num]
            end
          elsif was_enabled # disabled
            @gba.scheduler.clear(EVENT_TYPES[num])
          end
        end
      else
        @tmd[num] = (@tmd[num] & mask) | value
      end
    end
  end
end
