require "./arm/*"
require "./thumb/*"

class CPU
  include ARM
  include THUMB

  class PSR < BitField(UInt32)
    bool negative
    bool zero
    bool carry
    bool overflow
    num reserved, 20
    bool irq_disable
    bool fiq_disable
    bool thumb
    num mode, 5
  end

  @r = Slice(Word).new 16
  @cpsr : PSR
  @pipeline = Deque(Word).new 2
  getter lut : Slice(Proc(Word, Nil)) { fill_lut }
  getter thumb_lut : Slice(Proc(Word, Nil)) { fill_thumb_lut }

  def initialize(@gba : GBA)
    @r[0] = 0x08000000
    @r[1] = 0x000000EA
    @r[13] = 0x03007F00
    @r[15] = 0x08000000
    @cpsr = PSR.new 0x6000001F
  end

  def fill_pipeline : Nil
    while @pipeline.size < 2
      if @cpsr.thumb
        log "Fetch pc: #{hex_str @r[15]}, instr: #{hex_str @gba.bus.read_half(@r[15]).to_u16}"
        @pipeline << @gba.bus.read_half @r[15]
        @r[15] &+= 2
      else
        log "Fetch pc: #{hex_str @r[15]}, instr: #{hex_str @gba.bus.read_word @r[15]}"
        @pipeline << @gba.bus.read_word @r[15]
        @r[15] &+= 4
      end
    end
  end

  def clear_pipeline : Nil
    log "Clearing pipeline"
    @pipeline.clear
  end

  def tick : Nil
    fill_pipeline
    instr = @pipeline.shift
    print_state instr
    if @cpsr.thumb
      thumb_execute instr
    else
      arm_execute instr
    end
  end

  def print_state(instr : Word) : Nil
    {% if flag? :trace %}
      @r.each do |reg|
        trace "#{hex_str reg, prefix: false} ", newline: false
      end
      if @cpsr.thumb
        trace "cpsr: #{hex_str @cpsr.value, prefix: false} |     #{hex_str instr.to_u16, prefix: false}"
      else
        trace "cpsr: #{hex_str @cpsr.value, prefix: false} | #{hex_str instr, prefix: false}"
      end
    {% end %}
  end
end
