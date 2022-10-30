module GBA
  # A super minimalistic FIFO queue implementation optimized for
  # use as an ARM instruction pipeline.
  class Pipeline
    @buffer = Slice(UInt32).new 2
    @pos = 0
    @size = 0

    def push(instr : UInt32) : Nil
      raise "Pushing to full pipeline" if @size == 2
      address = (@pos + @size) & 1
      @buffer[address] = instr
      @size += 1
    end

    def shift : UInt32
      @size -= 1
      val = @buffer[@pos]
      @pos = (@pos + 1) & 1
      val
    end

    def peek : UInt32
      @buffer[@pos]
    end

    def clear : Nil
      @size = 0
    end

    def size : Int32
      @size
    end
  end
end
