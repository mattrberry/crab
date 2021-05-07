class Scheduler
  enum EventType
    # Shared
    DEFAULT
    APU
    APUChannel1
    APUChannel2
    APUChannel3
    APUChannel4
    HandleInput
    # GB
    IME
    # GBA
    Timer0
    Timer1
    Timer2
    Timer3
  end

  private record Event, cycles : UInt64, proc : Proc(Nil), type : EventType

  @events : Deque(Event) = Deque(Event).new 10
  getter cycles : UInt64 = 0
  @next_event : UInt64 = UInt64::MAX

  @current_speed : UInt8 = 0

  def schedule(cycles : Int, proc : Proc(Nil), type = EventType::DEFAULT) : Nil
    self << Event.new @cycles + cycles, proc, type
  end

  def schedule_gb(cycles : Int, proc : Proc(Nil), type : EventType) : Nil
    cycles = cycles << @current_speed unless type == EventType::IME
    schedule(cycles, proc, type)
  end

  @[AlwaysInline]
  def <<(event : Event) : Nil
    idx = @events.bsearch_index { |e| e.cycles > event.cycles }
    unless idx.nil?
      @events.insert(idx, event)
    else
      @events << event
    end
    @next_event = @events[0].cycles
  end

  def clear(type : EventType) : Nil
    @events.reject! { |event| event.type == type }
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

  def fast_forward : Nil
    @cycles = @next_event
    call_current
  end

  # Set the CGB current speed to 1x (0) or 2x (1)
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
end
