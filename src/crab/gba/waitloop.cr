module GBA
  module Waitloop
    # Whether waitloop detection should be attempted.
    property attempt_waitloop_detection : Bool = true

    # Whether to try caching successful and unsuccessful branch destinations.
    property cache_waitloop_results : Bool = true

    # The previous branch destination.
    @branch_dest = 0_u32

    # Collection of branch destinations identified as waitloops.
    @identified_waitloops = Array(UInt32).new

    # Collection of branch destinations identified as non-waitloops.
    @identified_non_waitloops = Array(UInt32).new

    # Flags when a waitloop is detected. Used by the CPU to fast-forward.
    @entered_waitloop = false

    # Table to quickly look up an instruction's class.
    getter waitloop_instr_lut : Slice(Instruction.class) { build_lut }

    # Attempt to detect a waitloop. Assumes thumb instructions.
    def analyze_loop(start_addr : UInt32, end_addr : UInt32) : Nil
      return unless @attempt_waitloop_detection
      return unless start_addr == @branch_dest
      return unless start_addr < end_addr && 2 <= end_addr - start_addr <= 8 # only analyze up to 4 thumb instruction
      if @cache_waitloop_results
        if @identified_waitloops.includes?(start_addr)
          @entered_waitloop = true
          return
        end
        return if @identified_non_waitloops.includes?(start_addr)
      end

      written_bits = never_write = 0_u16
      (start_addr...end_addr).step(2) do |addr|
        instr = @gba.bus.read_half_internal(addr)
        parsed_instr = waitloop_instr_lut[instr >> 8].parse?(instr)

        unless parsed_instr && parsed_instr.read_only?
          @identified_non_waitloops.push(start_addr) if @cache_waitloop_results
          return
        end

        never_write |= parsed_instr.read_bits & ~written_bits
        if written_bits & never_write > 0 # first write to a register was after a read, which could indicate an impure loop.
          @identified_non_waitloops.push(start_addr) if @cache_waitloop_results
          return
        end

        written_bits |= parsed_instr.write_bits
      end

      @identified_waitloops.push(start_addr) if @cache_waitloop_results
      @entered_waitloop = true
    ensure
      @branch_dest = start_addr
    end

    def build_lut : Slice(Instruction.class)
      Slice(Instruction.class).new(256) do |idx|
        case
        when idx & 0b11110000 == 0b11110000 then LongBranchLink
        when idx & 0b11111000 == 0b11100000 then UnconditionalBranch
        when idx & 0b11111111 == 0b11011111 then SoftwareInterrupt
        when idx & 0b11110000 == 0b11010000 then ConditionalBranch
        when idx & 0b11110000 == 0b11000000 then MultipleLoadStore
        when idx & 0b11110110 == 0b10110100 then PushPopRegisters
        when idx & 0b11111111 == 0b10110000 then AddOffsetToStackPointer
        when idx & 0b11110000 == 0b10100000 then LoadAddress
        when idx & 0b11110000 == 0b10010000 then SpRelativeLoadStore
        when idx & 0b11110000 == 0b10000000 then LoadStoreHalfword
        when idx & 0b11100000 == 0b01100000 then LoadStoreImmediateOffset
        when idx & 0b11110010 == 0b01010010 then LoadStoreSignExtended
        when idx & 0b11110010 == 0b01010000 then LoadStoreRegisterOffset
        when idx & 0b11111000 == 0b01001000 then PcRelativeLoad
        when idx & 0b11111100 == 0b01000100 then HighRegBranchExchange
        when idx & 0b11111100 == 0b01000000 then AluOperations
        when idx & 0b11100000 == 0b00100000 then MoveCompareAddSubtract
        when idx & 0b11111000 == 0b00011000 then AddSubtract
        when idx & 0b11100000 == 0b00000000 then MoveShiftedRegister
        else                                     Unimplemented
        end
      end
    end

    abstract struct Instruction
      # Attempt to parse the instruction. Nilable to support unimplemented insts.
      def self.parse?(instruction : UInt16) : Instruction?
      end

      # Indicates that this instruction doesn't attempt to write to storage.
      def read_only?
        false
      end

      # Each set bit indicates a register this instruction reads from.
      def read_bits : UInt16
        0xFF_u16
      end

      # Each set bit indicates a register this instruction writes to.
      def write_bits : UInt16
        0xFF_u16
      end
    end

    struct LongBranchLink < Instruction
    end

    struct UnconditionalBranch < Instruction
    end

    struct SoftwareInterrupt < Instruction
    end

    struct ConditionalBranch < Instruction
      def initialize(@cond : UInt16, @offset : Int32)
      end

      def read_only? : Bool
        true
      end

      def read_bits : UInt16
        0_u16
      end

      def write_bits : UInt16
        0_u16
      end

      def self.parse?(instr : UInt16) : ConditionalBranch
        cond = bits(instr, 8..11)
        offset = bits(instr, 0..7).to_i8!.to_i32
        new(cond, offset)
      end
    end

    struct MultipleLoadStore < Instruction
    end

    struct PushPopRegisters < Instruction
    end

    struct AddOffsetToStackPointer < Instruction
    end

    struct LoadAddress < Instruction
    end

    struct SpRelativeLoadStore < Instruction
    end

    struct LoadStoreHalfword < Instruction
      def initialize(@load : Bool, @offset : UInt16, @rb : UInt16, @rd : UInt16)
      end

      def read_only? : Bool
        @load
      end

      def read_bits : UInt16
        res = 1_u16 << @rb
        res |= 1_u16 << @rd unless @load
        res
      end

      def write_bits : UInt16
        if @load
          1_u16 << @rd
        else
          0_u16
        end
      end

      def self.parse?(instr : UInt16) : LoadStoreHalfword
        load = bit?(instr, 11)
        offset = bits(instr, 6..10)
        rb = bits(instr, 3..5)
        rd = bits(instr, 0..2)
        new(load, offset, rb, rd)
      end
    end

    struct LoadStoreImmediateOffset < Instruction
    end

    struct LoadStoreSignExtended < Instruction
    end

    struct LoadStoreRegisterOffset < Instruction
    end

    struct PcRelativeLoad < Instruction
    end

    struct HighRegBranchExchange < Instruction
    end

    struct AluOperations < Instruction
      def initialize(@op : UInt16, @rs : UInt16, @rd : UInt16)
      end

      def read_only? : Bool
        true
      end

      def read_bits : UInt16
        1_u16 << @rs | 1_u16 << @rd
      end

      def write_bits : UInt16
        return 0_u16 if @op == 0b1000_u16 || @op == 0b1010_u16 || @op == 0b1011_u16
        1_u16 << @rd
      end

      def self.parse?(instr : UInt16) : AluOperations
        op = bits(instr, 6..9)
        rs = bits(instr, 3..5)
        rd = bits(instr, 0..2)
        new(op, rs, rd)
      end
    end

    struct MoveCompareAddSubtract < Instruction
      def initialize(@op : UInt16, @rd : UInt16, @offset : UInt16)
      end

      def read_only? : Bool
        true
      end

      def read_bits : UInt16
        return 0_u16 if @op == 0
        1_u16 << @rd
      end

      def write_bits : UInt16
        return 0_u16 if @op == 1
        1_u16 << @rd
      end

      def self.parse?(instr : UInt16) : MoveCompareAddSubtract
        op = bits(instr, 11..12)
        rd = bits(instr, 8..10)
        offset = bits(instr, 0..7)
        new(op, rd, offset)
      end
    end

    struct AddSubtract < Instruction
      def initialize(@imm_flag : Bool, @sub : Bool, @imm_or_rn : UInt16, @rs : UInt16, @rd : UInt16)
      end

      def read_only? : Bool
        true
      end

      def read_bits : UInt16
        res = 1_u16 << @rs
        res |= 1_u16 << @imm_or_rn unless @imm_flag
        res
      end

      def write_bits : UInt16
        1_u16 << @rd
      end

      def self.parse?(instr : UInt16) : AddSubtract
        imm_flag = bit?(instr, 10)
        sub = bit?(instr, 9)
        imm_or_rn = bits(instr, 6..8)
        rs = bits(instr, 3..5)
        rd = bits(instr, 0..2)
        new(imm_flag, sub, imm_or_rn, rs, rd)
      end
    end

    struct MoveShiftedRegister < Instruction
    end

    struct Unimplemented < Instruction
    end
  end
end
