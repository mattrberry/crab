module GB
  class Scheduler
    enum EventType
      APU
      APUChannel1
      APUChannel2
      APUChannel3
      APUChannel4
      IME
      HandleInput
    end

    private record Event, cycles : UInt64, type : EventType, proc : Proc(Void) do
      def to_s(io)
        io << "Event(cycles: #{cycles}, type: #{type}, proc: #{proc})"
      end
    end

    @events : Deque(Event) = Deque(Event).new 10
    @cycles : UInt64 = 0
    @next_event : UInt64 = UInt64::MAX

    @current_speed : UInt8 = 0

    def schedule(cycles : Int, type : EventType, proc : Proc(Void)) : Nil
      cycles = cycles << @current_speed unless type == EventType::IME
      self << Event.new @cycles + cycles, type, proc
    end

    def schedule(cycles : Int, type : EventType, &block : ->)
      cycles = cycles << @current_speed unless type == EventType::IME
      self << Event.new @cycles + cycles, type, block
    end

    def clear(type : EventType) : Nil
      @events.reject! { |event| event.type == type }
    end

    # Set the current speed to 1x (0) or 2x (1)
    def speed_mode=(speed : UInt8) : Nil
      @current_speed = speed
      @events.each_with_index do |event, idx|
        unless event.type == EventType::IME
          remaining_cycles = event.cycles - @cycles
          # divide by two if entering single speed, else multiply by two
          offset = remaining_cycles >> (@current_speed - speed)
          @events[idx] = event.copy_with cycles: @cycles + offset
        end
      end
    end

    def <<(event : Event) : Nil
      idx = @events.bsearch_index { |e, i| e.cycles > event.cycles }
      unless idx.nil?
        @events.insert(idx, event)
      else
        @events << event
      end
      @next_event = @events[0].cycles
    end

    def tick(cycles : Int) : Nil
      if @cycles + cycles < @next_event
        @cycles += cycles
      else
        cycles.times do
          @cycles += 1
          call_current
        end
      end
    end

    def call_current : Nil
      loop do
        event = @events.first?
        if event && @cycles >= event.cycles
          event.proc.call
          @events.shift
        else
          if event
            @next_event = event.cycles
          else
            @next_event = UInt64::MAX
          end
          return
        end
      end
    end
  end
end
