require "compiler/crystal/formatter"
require "compiler/crystal/command/format"
require "http/client"
require "json"

OPCODE_JSON_URL = "https://raw.githubusercontent.com/izik1/gbops/master/dmgops.json"
FILE_PATH       = "src/cryboy/opcodes.cr"

module GB
  module DmgOps
    enum FlagOp
      ZERO
      ONE
      UNCHANGED
      DEFAULT
    end

    class Flags
      include JSON::Serializable

      @[JSON::Field(key: "Z")]
      @z : String
      @[JSON::Field(key: "N")]
      @n : String
      @[JSON::Field(key: "H")]
      @h : String
      @[JSON::Field(key: "C")]
      @c : String

      def str_to_flagop(s : String) : FlagOp
        case s
        when "0" then FlagOp::ZERO
        when "1" then FlagOp::ONE
        when "-" then FlagOp::UNCHANGED
        else          FlagOp::DEFAULT
        end
      end

      def z : FlagOp
        str_to_flagop @z
      end

      def n : FlagOp
        str_to_flagop @n
      end

      def h : FlagOp
        str_to_flagop @h
      end

      def c : FlagOp
        str_to_flagop @c
      end
    end

    enum Group
      X8_LSM
      X16_LSM
      X8_ALU
      X16_ALU
      X8_RSB
      CONTROL_BR
      CONTROL_MISC
    end

    class Operation
      include JSON::Serializable

      @[JSON::Field(key: "Name")]
      property name : String
      @[JSON::Field(key: "Group")]
      @group : String
      @[JSON::Field(key: "TCyclesNoBranch")]
      property cycles : UInt8
      @[JSON::Field(key: "TCyclesBranch")]
      property cycles_branch : UInt8
      @[JSON::Field(key: "Length")]
      property length : UInt8
      @[JSON::Field(key: "Flags")]
      property flags : Flags

      # read the operation type from the name
      def type : String
        @name.split.first
      end

      # read the operation operands from the name
      def operands : Array(String)
        split = name.split(limit: 2)
        split.size <= 1 ? [] of String : split[1].split(',').map { |operand| normalize_operand operand }
      end

      # read the group as a Group enum
      def group : Group
        case @group
        when "x8/lsm"       then Group::X8_LSM
        when "x16/lsm"      then Group::X16_LSM
        when "x8/alu"       then Group::X8_ALU
        when "x16/alu"      then Group::X16_ALU
        when "x8/rsb"       then Group::X8_RSB
        when "control/br"   then Group::CONTROL_BR
        when "control/misc" then Group::CONTROL_MISC
        else                     raise "Failed to match group #{@group}"
        end
      end

      # normalize an operand to work with the existing cpu methods/fields
      def normalize_operand(operand : String) : String
        operand = operand.downcase
        operand = operand.sub "(", "cpu.memory["
        operand = operand.sub ")", "]"
        operand = operand.sub "hl+", "((hl &+= 1) &- 1)"
        operand = operand.sub "hl-", "((hl &-= 1) &+ 1)"
        operand = operand.sub "ff00+", "0xFF00 &+ "
        operand = operand.sub "sp+i8", "sp &+ i8"
        operand = operand.sub /(\d\d)h/, "0x\\1_u16"
        if group == Group::CONTROL_BR || group == Group::CONTROL_MISC
          # distinguish between "flag c" and "register z"
          operand = operand.sub /\bz\b/, "cpu.f_z"
          operand = operand.sub /\bnz\b/, "cpu.f_nz"
          operand = operand.sub /\bc\b/, "cpu.f_c"
          operand = operand.sub /\bnc\b/, "cpu.f_nc"
        end
        operand = operand.sub "pc", "cpu.pc"
        operand = operand.sub "sp", "cpu.sp"
        operand = operand.sub "af", "cpu.af"
        operand = operand.sub "bc", "cpu.bc"
        operand = operand.sub "de", "cpu.de"
        operand = operand.sub "hl", "cpu.hl"
        operand = operand.sub /\ba\b/, "cpu.a"
        operand = operand.sub /\bf\b/, "cpu.f"
        operand = operand.sub /\bb\b/, "cpu.b"
        operand = operand.sub /\bc\b/, "cpu.c"
        operand = operand.sub /\bd\b/, "cpu.d"
        operand = operand.sub /\be\b/, "cpu.e"
        operand = operand.sub /\bh\b/, "cpu.h"
        operand = operand.sub /\bl\b/, "cpu.l"
        operand = operand.sub "cpu.memory[cpu.hl]", "cpu.memory_at_hl"
        operand
      end

      # set u8, u16, and i8 if necessary
      def assign_extra_integers : Array(String)
        if name.includes? "u8"
          return ["u8 = cpu.memory[cpu.pc]", "cpu.inc_pc"]
        elsif name.includes? "u16"
          return ["u16 = cpu.memory[cpu.pc].to_u16", "cpu.inc_pc", "u16 |= cpu.memory[cpu.pc].to_u16 << 8", "cpu.inc_pc"]
        elsif name.includes? "i8"
          return ["i8 = cpu.memory[cpu.pc].to_i8!", "cpu.inc_pc"]
        end
        [] of String
      end

      # create a branch condition
      def branch(cond : String, body : Array(String)) : Array(String)
        ["if #{cond}"] + body + set_reset_flags + ["return #{cycles_branch}", "end"]
      end

      # set flag z to the given value if specified by this operation
      def set_flag_z(o : Object) : Array(String)
        flags.z == FlagOp::DEFAULT ? set_flag_z! o : [] of String
      end

      # set flag z to the given value
      def set_flag_z!(o : Object) : Array(String)
        ["cpu.f_z = #{o}"]
      end

      # set flag n to the given value if specified by this operation
      def set_flag_n(o : Object) : Array(String)
        flags.n == FlagOp::DEFAULT ? set_flag_n! o : [] of String
      end

      # set flag n to the given value
      def set_flag_n!(o : Object) : Array(String)
        ["cpu.f_n = #{o}"]
      end

      # set flag h to the given value if specified by this operation
      def set_flag_h(o : Object) : Array(String)
        flags.h == FlagOp::DEFAULT ? set_flag_h! o : [] of String
      end

      # set flag h to the given value
      def set_flag_h!(o : Object) : Array(String)
        ["cpu.f_h = #{o}"]
      end

      # set flag c to the given value if specified by this operation
      def set_flag_c(o : Object) : Array(String)
        flags.c == FlagOp::DEFAULT ? set_flag_c! o : [] of String
      end

      # set flag c to the given value
      def set_flag_c!(o : Object) : Array(String)
        ["cpu.f_c = #{o}"]
      end

      # generate code to set/reset flags if necessary
      def set_reset_flags : Array(String)
        (flags.z == FlagOp::ZERO ? set_flag_z! false : [] of String) +
          (flags.z == FlagOp::ONE ? set_flag_z! true : [] of String) +
          (flags.n == FlagOp::ZERO ? set_flag_n! false : [] of String) +
          (flags.n == FlagOp::ONE ? set_flag_n! true : [] of String) +
          (flags.h == FlagOp::ZERO ? set_flag_h! false : [] of String) +
          (flags.h == FlagOp::ONE ? set_flag_h! true : [] of String) +
          (flags.c == FlagOp::ZERO ? set_flag_c! false : [] of String) +
          (flags.c == FlagOp::ONE ? set_flag_c! true : [] of String)
      end

      # switch over operation type and generate code
      private def codegen_help : Array(String)
        case type
        when "ADC"
          to, from = operands
          if to == from
            ["carry = cpu.f_c ? 0x01 : 0x00"] +
              set_flag_h("(#{to} & 0x0F) + (#{from} & 0x0F) + carry > 0x0F") +
              set_flag_c("#{to} > 0x7F") +
              ["#{to} &+= #{from} &+ carry"] +
              set_flag_z("#{to} == 0")
          else
            ["carry = cpu.f_c ? 0x01 : 0x00"] +
              set_flag_h("(#{to} & 0x0F) + (#{from} & 0x0F) + carry > 0x0F") +
              ["#{to} &+= #{from} &+ carry"] +
              set_flag_z("#{to} == 0") +
              set_flag_c("#{to} < #{from}.to_u16 + carry")
          end
        when "ADD"
          to, from = operands
          if group == Group::X8_ALU
            if to == from
              set_flag_h("(#{to} & 0x0F) + (#{from} & 0x0F) > 0x0F") +
                set_flag_c("#{to} > 0x7F") +
                ["#{to} &+= #{from}"] +
                set_flag_z("#{to} == 0")
            else
              set_flag_h("(#{to} & 0x0F) + (#{from} & 0x0F) > 0x0F") +
                ["#{to} &+= #{from}"] +
                set_flag_z("#{to} == 0") +
                set_flag_c("#{to} < #{from}")
            end
          elsif group == Group::X16_ALU
            if from == "i8"
              ["r = cpu.sp &+ i8"] +
                set_flag_h("(cpu.sp ^ i8 ^ r) & 0x0010 != 0") +
                set_flag_c("(cpu.sp ^ i8 ^ r) & 0x0100 != 0") +
                ["cpu.sp = r"]
            elsif to == from
              set_flag_h("(#{to} & 0x0FFF).to_u32 + (#{from} & 0x0FFF) > 0x0FFF") +
                set_flag_c("#{to} > 0x7FFF") +
                ["#{to} &+= #{from}"]
            else
              set_flag_h("(#{to} & 0x0FFF).to_u32 + (#{from} & 0x0FFF) > 0x0FFF") +
                ["#{to} &+= #{from}"] +
                set_flag_c("#{to} < #{from}")
            end
          else
            raise "Invalid group #{group} for ADD."
          end
        when "AND"
          to, from = operands
          ["#{to} &= #{from}"] +
            set_flag_z("#{to} == 0")
        when "BIT"
          bit, reg = operands
          set_flag_z("#{reg} & (0x1 << #{bit}) == 0")
        when "CALL"
          instr = ["cpu.memory.tick_components", "cpu.memory[cpu.sp -= 2] = cpu.pc", "cpu.pc = u16"]
          if operands.size == 1
            instr
          else
            cond, _ = operands
            branch(cond, instr)
          end
        when "CCF"
          set_flag_c("!cpu.f_c")
        when "CP"
          to, from = operands
          set_flag_z("#{to} &- #{from} == 0") +
            set_flag_h("#{to} & 0xF < #{from} & 0xF") +
            set_flag_c("#{to} < #{from}")
        when "CPL"
          ["cpu.a = ~cpu.a"]
        when "DAA"
          [
            "if cpu.f_n # last op was a subtraction",
            "  cpu.a &-= 0x60 if cpu.f_c",
            "  cpu.a &-= 0x06 if cpu.f_h",
            "else # last op was an addition",
            "  if cpu.f_c || cpu.a > 0x99",
            "    cpu.a &+= 0x60",
            "    cpu.f_c = true",
            "  end",
            "  if cpu.f_h || cpu.a & 0x0F > 0x09",
            "    cpu.a &+= 0x06",
            "  end",
            "end",
          ] +
            set_flag_z("cpu.a == 0")
        when "DEC"
          to = operands[0]
          ["#{to} &-= 1"] +
            set_flag_z("#{to} == 0") +
            set_flag_h("#{to} & 0x0F == 0x0F")
        when "DI"
          ["cpu.ime = false"]
        when "EI"
          ["cpu.scheduler.schedule(4, Scheduler::EventType::IME) { cpu.ime = true }"]
        when "HALT"
          ["cpu.halt"]
        when "INC"
          to = operands[0]
          set_flag_h("#{to} & 0x0F == 0x0F") +
            ["#{to} &+= 1"] +
            set_flag_z("#{to} == 0")
        when "JP"
          if operands.size == 1
            ["cpu.pc = #{operands[0]}"]
          else
            cond, loc = operands
            branch(cond, ["cpu.pc = #{loc}"])
          end
        when "JR"
          instr = ["cpu.pc &+= i8"]
          if operands.size == 1
            instr
          else
            cond, _ = operands
            branch(cond, instr)
          end
        when "LD"
          to, from = operands
          ["#{to} = #{from}"] +
            # the following flags _only_ apply to `LD HL, SP + i8`
            set_flag_h("(cpu.sp ^ i8 ^ cpu.hl) & 0x0010 != 0") +
            set_flag_c("(cpu.sp ^ i8 ^ cpu.hl) & 0x0100 != 0")
        when "NOP"
          [] of String
        when "OR"
          to, from = operands
          ["#{to} |= #{from}"] +
            set_flag_z("#{to} == 0")
        when "POP"
          reg = operands[0]
          ["#{reg} = cpu.memory.read_word (cpu.sp += 2) - 2"] +
            set_flag_z("#{reg} & (0x1 << 7)") +
            set_flag_n("#{reg} & (0x1 << 6)") +
            set_flag_h("#{reg} & (0x1 << 5)") +
            set_flag_c("#{reg} & (0x1 << 4)")
        when "PREFIX"
          [
            "# todo: This should operate as a seperate instruction, but can't be interrupted.",
            "#       This will require a restructure where the CPU leads the timing, rather than the PPU.",
            "#       https://discordapp.com/channels/465585922579103744/465586075830845475/712358911151177818",
            "#       https://discordapp.com/channels/465585922579103744/465586075830845475/712359253255520328",
            "cycles = Opcodes::PREFIXED[cpu.memory[cpu.pc]].call cpu",
            "return cycles",
          ]
        when "PUSH"
          [
            "cpu.memory.tick_components",
            "cpu.memory[cpu.sp -= 2] = #{operands[0]}",
          ]
        when "RES"
          bit, reg = operands
          ["#{reg} &= ~(0x1 << #{bit})"]
        when "RET"
          instr = ["cpu.pc = cpu.memory.read_word cpu.sp", "cpu.sp += 2"]
          if operands.size == 0
            instr
          else
            cond = operands[0]
            branch(cond, ["cpu.memory.tick_components"] + instr)
          end
        when "RETI"
          ["cpu.ime = true", "cpu.pc = cpu.memory.read_word cpu.sp", "cpu.sp += 0x02"]
        when "RL"
          reg = operands[0]
          ["carry = #{reg} & 0x80", "#{reg} = (#{reg} << 1) + (cpu.f_c ? 0x01 : 0x00)"] +
            set_flag_z("#{reg} == 0") +
            set_flag_c("carry")
        when "RLA"
          ["carry = cpu.a & 0x80", "cpu.a = (cpu.a << 1) + (cpu.f_c ? 0x01 : 0x00)"] +
            set_flag_c("carry")
        when "RLC"
          reg = operands[0]
          ["#{reg} = (#{reg} << 1) + (#{reg} >> 7)"] +
            set_flag_z("#{reg} == 0") +
            set_flag_c("#{reg} & 0x01")
        when "RLCA"
          ["cpu.a = (cpu.a << 1) + (cpu.a >> 7)"] +
            set_flag_c("cpu.a & 0x01")
        when "RR"
          reg = operands[0]
          ["carry = #{reg} & 0x01", "#{reg} = (#{reg} >> 1) + (cpu.f_c ? 0x80 : 0x00)"] +
            set_flag_z("#{reg} == 0") +
            set_flag_c("carry")
        when "RRA"
          ["carry = cpu.a & 0x01", "cpu.a = (cpu.a >> 1) + (cpu.f_c ? 0x80 : 0x00)"] +
            set_flag_c("carry")
        when "RRC"
          reg = operands[0]
          ["#{reg} = (#{reg} >> 1) + (#{reg} << 7)"] +
            set_flag_z("#{reg} == 0") +
            set_flag_c("#{reg} & 0x80")
        when "RRCA"
          ["cpu.a = (cpu.a >> 1) + (cpu.a << 7)"] +
            set_flag_c("cpu.a & 0x80")
        when "RST"
          ["cpu.memory.tick_components", "cpu.memory[cpu.sp -= 2] = cpu.pc", "cpu.pc = #{operands[0]}"]
        when "SBC"
          to, from = operands
          ["to_sub = #{from}.to_u16 + (cpu.f_c ? 0x01 : 0x00)"] +
            set_flag_h("(#{to} & 0x0F) < (#{from} & 0x0F) + (cpu.f_c ? 0x01 : 0x00)") +
            set_flag_c("#{to} < to_sub") +
            ["#{to} &-= to_sub"] +
            set_flag_z("#{to} == 0")
        when "SCF"
          # should already be covered by `set_reset_flags`
          [] of String
        when "SET"
          bit, reg = operands
          ["#{reg} |= (0x1 << #{bit})"]
        when "SLA"
          reg = operands[0]
          set_flag_c("#{reg} & 0x80") +
            ["#{reg} <<= 1"] +
            set_flag_z("#{reg} == 0")
        when "SRA"
          reg = operands[0]
          set_flag_c("#{reg} & 0x01") +
            ["#{reg} = (#{reg} >> 1) + (#{reg} & 0x80)"] +
            set_flag_z("#{reg} == 0")
        when "SRL"
          reg = operands[0]
          set_flag_c("#{reg} & 0x1") +
            ["#{reg} >>= 1"] +
            set_flag_z("#{reg} == 0")
        when "STOP"
          ["# todo: see if something more needs to happen here...", "cpu.inc_pc", "cpu.memory.stop_instr"]
        when "SUB"
          to, from = operands
          set_flag_h("#{to} & 0x0F < #{from} & 0x0F") +
            set_flag_c("#{to} < #{from}") +
            ["#{to} &-= #{from}"] +
            set_flag_z("#{to} == 0")
        when "SWAP"
          reg = operands[0]
          ["#{reg} = (#{reg} << 4) + (#{reg} >> 4)"] +
            set_flag_z("#{reg} == 0")
        when "UNUSED"
          ["# unused opcode"]
        when "XOR"
          to, from = operands
          ["#{to} ^= #{from}"] +
            set_flag_z("#{to} == 0")
        else ["raise \"Not currently supporting #{name}\""]
        end
      end

      # generate the code required to process this operation
      def codegen : Array(String)
        # ["cpu.print_state \"#{name}\""] +
        ["cpu.inc_pc"] +
          assign_extra_integers +
          codegen_help +
          set_reset_flags +
          ["return #{cycles}"]
      end
    end

    class Response
      include JSON::Serializable

      @[JSON::Field(key: "Unprefixed")]
      @operations : Array(Operation)
      @[JSON::Field(key: "CBPrefixed")]
      @cb_operations : Array(Operation)

      def codegen : Array(String)
        (["class Opcodes", "UNPREFIXED = ["] +
          @operations.map_with_index { |operation, index|
            ["# 0x#{index.to_s(16).rjust(2, '0').upcase} #{operation.name}", "->(cpu : CPU) {"] +
              operation.codegen +
              ["},"]
          } +
          ["]", "PREFIXED = ["] +
          @cb_operations.map_with_index { |operation, index|
            ["# 0x#{index.to_s(16).rjust(2, '0').upcase} #{operation.name}", "->(cpu : CPU) {"] +
              operation.codegen +
              ["},"]
          } +
          ["]", "end"]).flatten
      end
    end
  end

  HTTP::Client.get OPCODE_JSON_URL do |response|
    parsed = DmgOps::Response.from_json(response.body_io)
    codegen = parsed.codegen.join("\n")
    File.write FILE_PATH, codegen
    Crystal::Command::FormatCommand.new([FILE_PATH]).run
  end
end
