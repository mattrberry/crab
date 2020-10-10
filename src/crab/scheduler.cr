class Scheduler
  private record Event, cycles : UInt64, proc : Proc(Void)

  @events : Deque(Event) = Deque(Event).new 10
  @cycles : UInt64 = 0

  def schedule(cycles : Int, proc : Proc(Void)) : Nil
    self << Event.new @cycles + cycles, proc
  end

  def schedule(cycles : Int, &block : ->)
    self << Event.new @cycles + cycles, block
  end

  @[AlwaysInline]
  def <<(event : Event) : Nil
    idx = @events.bsearch_index { |e| e.cycles > event.cycles }
    unless idx.nil?
      @events.insert(idx, event)
    else
      @events << event
    end
  end

  def tick(cycles : Int) : Nil
    cycles.times do
      @cycles += 1
      call_current
    end
  end

  def call_current : Nil
    loop do
      event = @events.first?
      if event && @cycles >= event.cycles
        event.proc.call
        @events.shift
      else
        break
      end
    end
  end
end
