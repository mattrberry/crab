# A super minimalistic FIFO queue implementation optimized for
# use as an ARM instruction pipeline.
class Pipeline
  @buffer = Slice(Word).new 2
  @pos = 0
  @size = 0

  def push(instr : Word) : Nil
    raise "Pushing to full pipeline" if @size == 2
    index = (@pos + @size) & 1
    @buffer[index] = instr
    @size += 1
  end

  def shift : Word
    @size -= 1
    val = @buffer[@pos]
    @pos = (@pos + 1) & 1
    val
  end

  def clear : Nil
    @size = 0
  end

  def size : Int32
    @size
  end
end
