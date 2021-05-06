module GB
  class CPU
    CLOCK_SPEED = 4194304

    macro register(upper, lower, mask = nil)
      @{{upper.id}} : UInt8 = 0_u8
      @{{lower.id}} : UInt8 = 0_u8

      def {{upper.id}} : UInt8
        @{{upper.id}} {% if mask %} & ({{mask.id}} >> 8) {% end %}
      end

      def {{upper.id}}=(value : UInt8) : UInt8
        @{{upper.id}} = value {% if mask %} & ({{mask.id}} >> 8) {% end %}
      end

      def {{lower.id}} : UInt8
        @{{lower.id}} {% if mask %} & {{mask.id}} {% end %}
      end

      def {{lower.id}}=(value : UInt8) : UInt8
        @{{lower.id}} = value {% if mask %} & {{mask.id}} {% end %}
      end

      def {{upper.id}}{{lower.id}} : UInt16
        (self.{{upper}}.to_u16 << 8 | self.{{lower}}.to_u16).not_nil!
      end

      def {{upper.id}}{{lower.id}}=(value : UInt16) : UInt16
        self.{{upper.id}} = (value >> 8).to_u8
        self.{{lower.id}} = (value & 0xFF).to_u8
        self.{{upper.id}}{{lower.id}}
      end

      def {{upper.id}}{{lower.id}}=(value : UInt8) : UInt16
        self.{{upper.id}} = 0_u8
        self.{{lower.id}} = value
        self.{{upper.id}}{{lower.id}}
      end
    end

    macro flag(name, mask)
      def f_{{name.id}}=(on : Int | Bool)
        if on == false || on == 0
          self.f &= ~{{mask}}
        else
          self.f |= {{mask.id}}
        end
      end

      def f_{{name.id}} : Bool
        self.f & {{mask.id}} == {{mask.id}}
      end

      def f_n{{name.id}} : Bool
        !f_{{name.id}}
      end
    end

    register a, f, mask: 0xFFF0
    register b, c
    register d, e
    register h, l

    flag z, 0b10000000
    flag n, 0b01000000
    flag h, 0b00100000
    flag c, 0b00010000

    property pc : UInt16 = 0x0000
    property sp : UInt16 = 0x0000
    property memory : Memory
    property scheduler : Scheduler
    property ime : Bool = false
    @halted : Bool = false
    @halt_bug : Bool = false

    # hl reads are cached for each instruction
    # this is tracked here to reduce complications in the codegen
    @cached_hl_read : UInt8? = nil

    def initialize(@gb : GB)
      @memory = gb.memory
      @scheduler = gb.scheduler
    end

    def skip_boot : Nil
      @pc = 0x0100_u16
      @sp = 0xFFFE_u16
      self.af = 0x1180_u16
      self.bc = 0x0000_u16
      if @gb.cgb_ptr.value
        self.de = 0xFF56_u16
        self.hl = 0x000D_u16
      else
        self.de = 0x0008_u16
        self.hl = 0x007C_u16
      end
    end

    # service all interrupts
    def handle_interrupts
      if @gb.interrupts.interrupt_ready?
        @halted = false
        if @ime
          @ime = false
          @sp &-= 1
          @memory[@sp] = (@pc >> 8).to_u8
          interrupt = @gb.interrupts.highest_priority
          @sp &-= 1
          @memory[@sp] = @pc.to_u8!
          @pc = interrupt.value
          @gb.interrupts.clear interrupt
          @memory.tick_extra 20
        end
      end
    end

    def memory_at_hl : UInt8
      @cached_hl_read ||= @memory[self.hl]
      @cached_hl_read.not_nil!
    end

    def memory_at_hl=(val : UInt8) : Nil
      @cached_hl_read = val
      @memory[self.hl] = val
    end

    def print_state(op : String? = nil) : Nil
      puts "AF:#{hex_str self.af} BC:#{hex_str self.bc} DE:#{hex_str self.de} HL:#{hex_str self.hl} | SP:#{hex_str @sp} | PC:#{hex_str @pc} | OP:#{hex_str @memory.read_byte @pc} | IME:#{@ime}#{" | #{op}" if op}"
    end

    # Handle regular and obscure halting behavior
    def halt : Nil
      if !@ime && @gb.interrupts.interrupt_ready?
        @halt_bug = true
        @halted = false
      else
        @halted = true
      end
    end

    # Increment PC unless the halt bug should cause it to fail to increment
    def inc_pc : Nil
      if @halt_bug
        @halt_bug = false
      else
        @pc &+= 1
      end
    end

    # Runs for the specified number of machine cycles. If no argument provided,
    # runs only one instruction. Handles interrupts _after_ the instruction is
    # executed.
    def tick : Nil
      if @halted
        cycles_taken = 4
      else
        opcode = @memory[@pc]
        {% if flag? :graphics_test %}
          if opcode == 0x40
            @gb.ppu.write_png
            exit 0
          end
        {% end %}
        cycles_taken = Opcodes::UNPREFIXED[opcode].call self
      end
      @cached_hl_read = nil           # clear hl read cache
      @memory.tick_extra cycles_taken # tell memory component to tick extra cycles
      handle_interrupts
    end
  end
end
