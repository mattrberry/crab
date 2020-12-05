class Scheduler
  enum EventType
    DEFAULT
    APUChannel1
    APUChannel2
    APUChannel3
    APUChannel4
  end

  private record Event, cycles : UInt64, proc : Proc(Void), type : EventType

  @events : Deque(Event) = Deque(Event).new 10
  @cycles : UInt64 = 0
  @next_event : UInt64 = UInt64::MAX

  def schedule(cycles : Int, proc : Proc(Void), type = EventType::DEFAULT) : Nil
    self << Event.new @cycles + cycles, proc, type
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
    @events.delete_if { |event| event.type == type }
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
