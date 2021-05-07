module GB
  class Opcodes
    UNPREFIXED = [
      # 0x00 NOP
      ->(cpu : CPU) {
        cpu.inc_pc
        return 4
      },
      # 0x01 LD BC,u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        cpu.bc = u16
        return 12
      },
      # 0x02 LD (BC),A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory[cpu.bc] = cpu.a
        return 8
      },
      # 0x03 INC BC
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.bc &+= 1
        return 8
      },
      # 0x04 INC B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.b & 0x0F == 0x0F
        cpu.b &+= 1
        cpu.f_z = cpu.b == 0
        cpu.f_n = false
        return 4
      },
      # 0x05 DEC B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b &-= 1
        cpu.f_z = cpu.b == 0
        cpu.f_h = cpu.b & 0x0F == 0x0F
        cpu.f_n = true
        return 4
      },
      # 0x06 LD B,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.b = u8
        return 8
      },
      # 0x07 RLCA
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = (cpu.a << 1) + (cpu.a >> 7)
        cpu.f_c = cpu.a & 0x01
        cpu.f_z = false
        cpu.f_n = false
        cpu.f_h = false
        return 4
      },
      # 0x08 LD (u16),SP
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        cpu.memory[u16] = cpu.sp
        return 20
      },
      # 0x09 ADD HL,BC
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = (cpu.hl & 0x0FFF).to_u32 + (cpu.bc & 0x0FFF) > 0x0FFF
        cpu.hl &+= cpu.bc
        cpu.f_c = cpu.hl < cpu.bc
        cpu.f_n = false
        return 8
      },
      # 0x0A LD A,(BC)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.memory[cpu.bc]
        return 8
      },
      # 0x0B DEC BC
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.bc &-= 1
        return 8
      },
      # 0x0C INC C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.c & 0x0F == 0x0F
        cpu.c &+= 1
        cpu.f_z = cpu.c == 0
        cpu.f_n = false
        return 4
      },
      # 0x0D DEC C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c &-= 1
        cpu.f_z = cpu.c == 0
        cpu.f_h = cpu.c & 0x0F == 0x0F
        cpu.f_n = true
        return 4
      },
      # 0x0E LD C,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.c = u8
        return 8
      },
      # 0x0F RRCA
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = (cpu.a >> 1) + (cpu.a << 7)
        cpu.f_c = cpu.a & 0x80
        cpu.f_z = false
        cpu.f_n = false
        cpu.f_h = false
        return 4
      },
      # 0x10 STOP
      ->(cpu : CPU) {
        cpu.inc_pc
        # todo: see if something more needs to happen here...
        cpu.inc_pc
        cpu.memory.stop_instr
        return 4
      },
      # 0x11 LD DE,u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        cpu.de = u16
        return 12
      },
      # 0x12 LD (DE),A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory[cpu.de] = cpu.a
        return 8
      },
      # 0x13 INC DE
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.de &+= 1
        return 8
      },
      # 0x14 INC D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.d & 0x0F == 0x0F
        cpu.d &+= 1
        cpu.f_z = cpu.d == 0
        cpu.f_n = false
        return 4
      },
      # 0x15 DEC D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d &-= 1
        cpu.f_z = cpu.d == 0
        cpu.f_h = cpu.d & 0x0F == 0x0F
        cpu.f_n = true
        return 4
      },
      # 0x16 LD D,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.d = u8
        return 8
      },
      # 0x17 RLA
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.a & 0x80
        cpu.a = (cpu.a << 1) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_c = carry
        cpu.f_z = false
        cpu.f_n = false
        cpu.f_h = false
        return 4
      },
      # 0x18 JR i8
      ->(cpu : CPU) {
        cpu.inc_pc
        i8 = cpu.memory[cpu.pc].to_i8!
        cpu.inc_pc
        cpu.pc &+= i8
        return 12
      },
      # 0x19 ADD HL,DE
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = (cpu.hl & 0x0FFF).to_u32 + (cpu.de & 0x0FFF) > 0x0FFF
        cpu.hl &+= cpu.de
        cpu.f_c = cpu.hl < cpu.de
        cpu.f_n = false
        return 8
      },
      # 0x1A LD A,(DE)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.memory[cpu.de]
        return 8
      },
      # 0x1B DEC DE
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.de &-= 1
        return 8
      },
      # 0x1C INC E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.e & 0x0F == 0x0F
        cpu.e &+= 1
        cpu.f_z = cpu.e == 0
        cpu.f_n = false
        return 4
      },
      # 0x1D DEC E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e &-= 1
        cpu.f_z = cpu.e == 0
        cpu.f_h = cpu.e & 0x0F == 0x0F
        cpu.f_n = true
        return 4
      },
      # 0x1E LD E,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.e = u8
        return 8
      },
      # 0x1F RRA
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.a & 0x01
        cpu.a = (cpu.a >> 1) + (cpu.f_c ? 0x80 : 0x00)
        cpu.f_c = carry
        cpu.f_z = false
        cpu.f_n = false
        cpu.f_h = false
        return 4
      },
      # 0x20 JR NZ,i8
      ->(cpu : CPU) {
        cpu.inc_pc
        i8 = cpu.memory[cpu.pc].to_i8!
        cpu.inc_pc
        if cpu.f_nz
          cpu.pc &+= i8
          return 12
        end
        return 8
      },
      # 0x21 LD HL,u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        cpu.hl = u16
        return 12
      },
      # 0x22 LD (HL+),A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory[((cpu.hl &+= 1) &- 1)] = cpu.a
        return 8
      },
      # 0x23 INC HL
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.hl &+= 1
        return 8
      },
      # 0x24 INC H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.h & 0x0F == 0x0F
        cpu.h &+= 1
        cpu.f_z = cpu.h == 0
        cpu.f_n = false
        return 4
      },
      # 0x25 DEC H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h &-= 1
        cpu.f_z = cpu.h == 0
        cpu.f_h = cpu.h & 0x0F == 0x0F
        cpu.f_n = true
        return 4
      },
      # 0x26 LD H,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.h = u8
        return 8
      },
      # 0x27 DAA
      ->(cpu : CPU) {
        cpu.inc_pc
        if cpu.f_n # last op was a subtraction
          cpu.a &-= 0x60 if cpu.f_c
          cpu.a &-= 0x06 if cpu.f_h
        else # last op was an addition
          if cpu.f_c || cpu.a > 0x99
            cpu.a &+= 0x60
            cpu.f_c = true
          end
          if cpu.f_h || cpu.a & 0x0F > 0x09
            cpu.a &+= 0x06
          end
        end
        cpu.f_z = cpu.a == 0
        cpu.f_h = false
        return 4
      },
      # 0x28 JR Z,i8
      ->(cpu : CPU) {
        cpu.inc_pc
        i8 = cpu.memory[cpu.pc].to_i8!
        cpu.inc_pc
        if cpu.f_z
          cpu.pc &+= i8
          return 12
        end
        return 8
      },
      # 0x29 ADD HL,HL
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = (cpu.hl & 0x0FFF).to_u32 + (cpu.hl & 0x0FFF) > 0x0FFF
        cpu.f_c = cpu.hl > 0x7FFF
        cpu.hl &+= cpu.hl
        cpu.f_n = false
        return 8
      },
      # 0x2A LD A,(HL+)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.memory[((cpu.hl &+= 1) &- 1)]
        return 8
      },
      # 0x2B DEC HL
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.hl &-= 1
        return 8
      },
      # 0x2C INC L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.l & 0x0F == 0x0F
        cpu.l &+= 1
        cpu.f_z = cpu.l == 0
        cpu.f_n = false
        return 4
      },
      # 0x2D DEC L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l &-= 1
        cpu.f_z = cpu.l == 0
        cpu.f_h = cpu.l & 0x0F == 0x0F
        cpu.f_n = true
        return 4
      },
      # 0x2E LD L,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.l = u8
        return 8
      },
      # 0x2F CPL
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = ~cpu.a
        cpu.f_n = true
        cpu.f_h = true
        return 4
      },
      # 0x30 JR NC,i8
      ->(cpu : CPU) {
        cpu.inc_pc
        i8 = cpu.memory[cpu.pc].to_i8!
        cpu.inc_pc
        if cpu.f_nc
          cpu.pc &+= i8
          return 12
        end
        return 8
      },
      # 0x31 LD SP,u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        cpu.sp = u16
        return 12
      },
      # 0x32 LD (HL-),A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory[((cpu.hl &-= 1) &+ 1)] = cpu.a
        return 8
      },
      # 0x33 INC SP
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.sp &+= 1
        return 8
      },
      # 0x34 INC (HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.memory_at_hl & 0x0F == 0x0F
        cpu.memory_at_hl &+= 1
        cpu.f_z = cpu.memory_at_hl == 0
        cpu.f_n = false
        return 12
      },
      # 0x35 DEC (HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl &-= 1
        cpu.f_z = cpu.memory_at_hl == 0
        cpu.f_h = cpu.memory_at_hl & 0x0F == 0x0F
        cpu.f_n = true
        return 12
      },
      # 0x36 LD (HL),u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.memory_at_hl = u8
        return 12
      },
      # 0x37 SCF
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = true
        return 4
      },
      # 0x38 JR C,i8
      ->(cpu : CPU) {
        cpu.inc_pc
        i8 = cpu.memory[cpu.pc].to_i8!
        cpu.inc_pc
        if cpu.f_c
          cpu.pc &+= i8
          return 12
        end
        return 8
      },
      # 0x39 ADD HL,SP
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = (cpu.hl & 0x0FFF).to_u32 + (cpu.sp & 0x0FFF) > 0x0FFF
        cpu.hl &+= cpu.sp
        cpu.f_c = cpu.hl < cpu.sp
        cpu.f_n = false
        return 8
      },
      # 0x3A LD A,(HL-)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.memory[((cpu.hl &-= 1) &+ 1)]
        return 8
      },
      # 0x3B DEC SP
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.sp &-= 1
        return 8
      },
      # 0x3C INC A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.a & 0x0F == 0x0F
        cpu.a &+= 1
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        return 4
      },
      # 0x3D DEC A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &-= 1
        cpu.f_z = cpu.a == 0
        cpu.f_h = cpu.a & 0x0F == 0x0F
        cpu.f_n = true
        return 4
      },
      # 0x3E LD A,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.a = u8
        return 8
      },
      # 0x3F CCF
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = !cpu.f_c
        cpu.f_n = false
        cpu.f_h = false
        return 4
      },
      # 0x40 LD B,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b = cpu.b
        return 4
      },
      # 0x41 LD B,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b = cpu.c
        return 4
      },
      # 0x42 LD B,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b = cpu.d
        return 4
      },
      # 0x43 LD B,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b = cpu.e
        return 4
      },
      # 0x44 LD B,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b = cpu.h
        return 4
      },
      # 0x45 LD B,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b = cpu.l
        return 4
      },
      # 0x46 LD B,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b = cpu.memory_at_hl
        return 8
      },
      # 0x47 LD B,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b = cpu.a
        return 4
      },
      # 0x48 LD C,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c = cpu.b
        return 4
      },
      # 0x49 LD C,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c = cpu.c
        return 4
      },
      # 0x4A LD C,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c = cpu.d
        return 4
      },
      # 0x4B LD C,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c = cpu.e
        return 4
      },
      # 0x4C LD C,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c = cpu.h
        return 4
      },
      # 0x4D LD C,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c = cpu.l
        return 4
      },
      # 0x4E LD C,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c = cpu.memory_at_hl
        return 8
      },
      # 0x4F LD C,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c = cpu.a
        return 4
      },
      # 0x50 LD D,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d = cpu.b
        return 4
      },
      # 0x51 LD D,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d = cpu.c
        return 4
      },
      # 0x52 LD D,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d = cpu.d
        return 4
      },
      # 0x53 LD D,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d = cpu.e
        return 4
      },
      # 0x54 LD D,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d = cpu.h
        return 4
      },
      # 0x55 LD D,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d = cpu.l
        return 4
      },
      # 0x56 LD D,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d = cpu.memory_at_hl
        return 8
      },
      # 0x57 LD D,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d = cpu.a
        return 4
      },
      # 0x58 LD E,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e = cpu.b
        return 4
      },
      # 0x59 LD E,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e = cpu.c
        return 4
      },
      # 0x5A LD E,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e = cpu.d
        return 4
      },
      # 0x5B LD E,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e = cpu.e
        return 4
      },
      # 0x5C LD E,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e = cpu.h
        return 4
      },
      # 0x5D LD E,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e = cpu.l
        return 4
      },
      # 0x5E LD E,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e = cpu.memory_at_hl
        return 8
      },
      # 0x5F LD E,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e = cpu.a
        return 4
      },
      # 0x60 LD H,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h = cpu.b
        return 4
      },
      # 0x61 LD H,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h = cpu.c
        return 4
      },
      # 0x62 LD H,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h = cpu.d
        return 4
      },
      # 0x63 LD H,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h = cpu.e
        return 4
      },
      # 0x64 LD H,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h = cpu.h
        return 4
      },
      # 0x65 LD H,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h = cpu.l
        return 4
      },
      # 0x66 LD H,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h = cpu.memory_at_hl
        return 8
      },
      # 0x67 LD H,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h = cpu.a
        return 4
      },
      # 0x68 LD L,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l = cpu.b
        return 4
      },
      # 0x69 LD L,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l = cpu.c
        return 4
      },
      # 0x6A LD L,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l = cpu.d
        return 4
      },
      # 0x6B LD L,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l = cpu.e
        return 4
      },
      # 0x6C LD L,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l = cpu.h
        return 4
      },
      # 0x6D LD L,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l = cpu.l
        return 4
      },
      # 0x6E LD L,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l = cpu.memory_at_hl
        return 8
      },
      # 0x6F LD L,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l = cpu.a
        return 4
      },
      # 0x70 LD (HL),B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl = cpu.b
        return 8
      },
      # 0x71 LD (HL),C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl = cpu.c
        return 8
      },
      # 0x72 LD (HL),D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl = cpu.d
        return 8
      },
      # 0x73 LD (HL),E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl = cpu.e
        return 8
      },
      # 0x74 LD (HL),H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl = cpu.h
        return 8
      },
      # 0x75 LD (HL),L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl = cpu.l
        return 8
      },
      # 0x76 HALT
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.halt
        return 4
      },
      # 0x77 LD (HL),A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl = cpu.a
        return 8
      },
      # 0x78 LD A,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.b
        return 4
      },
      # 0x79 LD A,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.c
        return 4
      },
      # 0x7A LD A,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.d
        return 4
      },
      # 0x7B LD A,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.e
        return 4
      },
      # 0x7C LD A,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.h
        return 4
      },
      # 0x7D LD A,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.l
        return 4
      },
      # 0x7E LD A,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.memory_at_hl
        return 8
      },
      # 0x7F LD A,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.a
        return 4
      },
      # 0x80 ADD A,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = (cpu.a & 0x0F) + (cpu.b & 0x0F) > 0x0F
        cpu.a &+= cpu.b
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.b
        cpu.f_n = false
        return 4
      },
      # 0x81 ADD A,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = (cpu.a & 0x0F) + (cpu.c & 0x0F) > 0x0F
        cpu.a &+= cpu.c
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.c
        cpu.f_n = false
        return 4
      },
      # 0x82 ADD A,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = (cpu.a & 0x0F) + (cpu.d & 0x0F) > 0x0F
        cpu.a &+= cpu.d
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.d
        cpu.f_n = false
        return 4
      },
      # 0x83 ADD A,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = (cpu.a & 0x0F) + (cpu.e & 0x0F) > 0x0F
        cpu.a &+= cpu.e
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.e
        cpu.f_n = false
        return 4
      },
      # 0x84 ADD A,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = (cpu.a & 0x0F) + (cpu.h & 0x0F) > 0x0F
        cpu.a &+= cpu.h
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.h
        cpu.f_n = false
        return 4
      },
      # 0x85 ADD A,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = (cpu.a & 0x0F) + (cpu.l & 0x0F) > 0x0F
        cpu.a &+= cpu.l
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.l
        cpu.f_n = false
        return 4
      },
      # 0x86 ADD A,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = (cpu.a & 0x0F) + (cpu.memory_at_hl & 0x0F) > 0x0F
        cpu.a &+= cpu.memory_at_hl
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.memory_at_hl
        cpu.f_n = false
        return 8
      },
      # 0x87 ADD A,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = (cpu.a & 0x0F) + (cpu.a & 0x0F) > 0x0F
        cpu.f_c = cpu.a > 0x7F
        cpu.a &+= cpu.a
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        return 4
      },
      # 0x88 ADC A,B
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.f_c ? 0x01 : 0x00
        cpu.f_h = (cpu.a & 0x0F) + (cpu.b & 0x0F) + carry > 0x0F
        cpu.a &+= cpu.b &+ carry
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.b.to_u16 + carry
        cpu.f_n = false
        return 4
      },
      # 0x89 ADC A,C
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.f_c ? 0x01 : 0x00
        cpu.f_h = (cpu.a & 0x0F) + (cpu.c & 0x0F) + carry > 0x0F
        cpu.a &+= cpu.c &+ carry
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.c.to_u16 + carry
        cpu.f_n = false
        return 4
      },
      # 0x8A ADC A,D
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.f_c ? 0x01 : 0x00
        cpu.f_h = (cpu.a & 0x0F) + (cpu.d & 0x0F) + carry > 0x0F
        cpu.a &+= cpu.d &+ carry
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.d.to_u16 + carry
        cpu.f_n = false
        return 4
      },
      # 0x8B ADC A,E
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.f_c ? 0x01 : 0x00
        cpu.f_h = (cpu.a & 0x0F) + (cpu.e & 0x0F) + carry > 0x0F
        cpu.a &+= cpu.e &+ carry
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.e.to_u16 + carry
        cpu.f_n = false
        return 4
      },
      # 0x8C ADC A,H
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.f_c ? 0x01 : 0x00
        cpu.f_h = (cpu.a & 0x0F) + (cpu.h & 0x0F) + carry > 0x0F
        cpu.a &+= cpu.h &+ carry
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.h.to_u16 + carry
        cpu.f_n = false
        return 4
      },
      # 0x8D ADC A,L
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.f_c ? 0x01 : 0x00
        cpu.f_h = (cpu.a & 0x0F) + (cpu.l & 0x0F) + carry > 0x0F
        cpu.a &+= cpu.l &+ carry
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.l.to_u16 + carry
        cpu.f_n = false
        return 4
      },
      # 0x8E ADC A,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.f_c ? 0x01 : 0x00
        cpu.f_h = (cpu.a & 0x0F) + (cpu.memory_at_hl & 0x0F) + carry > 0x0F
        cpu.a &+= cpu.memory_at_hl &+ carry
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < cpu.memory_at_hl.to_u16 + carry
        cpu.f_n = false
        return 8
      },
      # 0x8F ADC A,A
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.f_c ? 0x01 : 0x00
        cpu.f_h = (cpu.a & 0x0F) + (cpu.a & 0x0F) + carry > 0x0F
        cpu.f_c = cpu.a > 0x7F
        cpu.a &+= cpu.a &+ carry
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        return 4
      },
      # 0x90 SUB A,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.a & 0x0F < cpu.b & 0x0F
        cpu.f_c = cpu.a < cpu.b
        cpu.a &-= cpu.b
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x91 SUB A,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.a & 0x0F < cpu.c & 0x0F
        cpu.f_c = cpu.a < cpu.c
        cpu.a &-= cpu.c
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x92 SUB A,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.a & 0x0F < cpu.d & 0x0F
        cpu.f_c = cpu.a < cpu.d
        cpu.a &-= cpu.d
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x93 SUB A,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.a & 0x0F < cpu.e & 0x0F
        cpu.f_c = cpu.a < cpu.e
        cpu.a &-= cpu.e
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x94 SUB A,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.a & 0x0F < cpu.h & 0x0F
        cpu.f_c = cpu.a < cpu.h
        cpu.a &-= cpu.h
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x95 SUB A,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.a & 0x0F < cpu.l & 0x0F
        cpu.f_c = cpu.a < cpu.l
        cpu.a &-= cpu.l
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x96 SUB A,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.a & 0x0F < cpu.memory_at_hl & 0x0F
        cpu.f_c = cpu.a < cpu.memory_at_hl
        cpu.a &-= cpu.memory_at_hl
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 8
      },
      # 0x97 SUB A,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_h = cpu.a & 0x0F < cpu.a & 0x0F
        cpu.f_c = cpu.a < cpu.a
        cpu.a &-= cpu.a
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x98 SBC A,B
      ->(cpu : CPU) {
        cpu.inc_pc
        to_sub = cpu.b.to_u16 + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_h = (cpu.a & 0x0F) < (cpu.b & 0x0F) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_c = cpu.a < to_sub
        cpu.a &-= to_sub
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x99 SBC A,C
      ->(cpu : CPU) {
        cpu.inc_pc
        to_sub = cpu.c.to_u16 + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_h = (cpu.a & 0x0F) < (cpu.c & 0x0F) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_c = cpu.a < to_sub
        cpu.a &-= to_sub
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x9A SBC A,D
      ->(cpu : CPU) {
        cpu.inc_pc
        to_sub = cpu.d.to_u16 + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_h = (cpu.a & 0x0F) < (cpu.d & 0x0F) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_c = cpu.a < to_sub
        cpu.a &-= to_sub
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x9B SBC A,E
      ->(cpu : CPU) {
        cpu.inc_pc
        to_sub = cpu.e.to_u16 + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_h = (cpu.a & 0x0F) < (cpu.e & 0x0F) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_c = cpu.a < to_sub
        cpu.a &-= to_sub
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x9C SBC A,H
      ->(cpu : CPU) {
        cpu.inc_pc
        to_sub = cpu.h.to_u16 + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_h = (cpu.a & 0x0F) < (cpu.h & 0x0F) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_c = cpu.a < to_sub
        cpu.a &-= to_sub
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x9D SBC A,L
      ->(cpu : CPU) {
        cpu.inc_pc
        to_sub = cpu.l.to_u16 + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_h = (cpu.a & 0x0F) < (cpu.l & 0x0F) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_c = cpu.a < to_sub
        cpu.a &-= to_sub
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0x9E SBC A,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        to_sub = cpu.memory_at_hl.to_u16 + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_h = (cpu.a & 0x0F) < (cpu.memory_at_hl & 0x0F) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_c = cpu.a < to_sub
        cpu.a &-= to_sub
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 8
      },
      # 0x9F SBC A,A
      ->(cpu : CPU) {
        cpu.inc_pc
        to_sub = cpu.a.to_u16 + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_h = (cpu.a & 0x0F) < (cpu.a & 0x0F) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_c = cpu.a < to_sub
        cpu.a &-= to_sub
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 4
      },
      # 0xA0 AND A,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= cpu.b
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = true
        cpu.f_c = false
        return 4
      },
      # 0xA1 AND A,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= cpu.c
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = true
        cpu.f_c = false
        return 4
      },
      # 0xA2 AND A,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= cpu.d
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = true
        cpu.f_c = false
        return 4
      },
      # 0xA3 AND A,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= cpu.e
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = true
        cpu.f_c = false
        return 4
      },
      # 0xA4 AND A,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= cpu.h
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = true
        cpu.f_c = false
        return 4
      },
      # 0xA5 AND A,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= cpu.l
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = true
        cpu.f_c = false
        return 4
      },
      # 0xA6 AND A,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= cpu.memory_at_hl
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = true
        cpu.f_c = false
        return 8
      },
      # 0xA7 AND A,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= cpu.a
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = true
        cpu.f_c = false
        return 4
      },
      # 0xA8 XOR A,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a ^= cpu.b
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xA9 XOR A,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a ^= cpu.c
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xAA XOR A,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a ^= cpu.d
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xAB XOR A,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a ^= cpu.e
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xAC XOR A,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a ^= cpu.h
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xAD XOR A,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a ^= cpu.l
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xAE XOR A,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a ^= cpu.memory_at_hl
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 8
      },
      # 0xAF XOR A,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a ^= cpu.a
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xB0 OR A,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= cpu.b
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xB1 OR A,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= cpu.c
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xB2 OR A,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= cpu.d
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xB3 OR A,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= cpu.e
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xB4 OR A,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= cpu.h
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xB5 OR A,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= cpu.l
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xB6 OR A,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= cpu.memory_at_hl
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 8
      },
      # 0xB7 OR A,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= cpu.a
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 4
      },
      # 0xB8 CP A,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a &- cpu.b == 0
        cpu.f_h = cpu.a & 0xF < cpu.b & 0xF
        cpu.f_c = cpu.a < cpu.b
        cpu.f_n = true
        return 4
      },
      # 0xB9 CP A,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a &- cpu.c == 0
        cpu.f_h = cpu.a & 0xF < cpu.c & 0xF
        cpu.f_c = cpu.a < cpu.c
        cpu.f_n = true
        return 4
      },
      # 0xBA CP A,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a &- cpu.d == 0
        cpu.f_h = cpu.a & 0xF < cpu.d & 0xF
        cpu.f_c = cpu.a < cpu.d
        cpu.f_n = true
        return 4
      },
      # 0xBB CP A,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a &- cpu.e == 0
        cpu.f_h = cpu.a & 0xF < cpu.e & 0xF
        cpu.f_c = cpu.a < cpu.e
        cpu.f_n = true
        return 4
      },
      # 0xBC CP A,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a &- cpu.h == 0
        cpu.f_h = cpu.a & 0xF < cpu.h & 0xF
        cpu.f_c = cpu.a < cpu.h
        cpu.f_n = true
        return 4
      },
      # 0xBD CP A,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a &- cpu.l == 0
        cpu.f_h = cpu.a & 0xF < cpu.l & 0xF
        cpu.f_c = cpu.a < cpu.l
        cpu.f_n = true
        return 4
      },
      # 0xBE CP A,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a &- cpu.memory_at_hl == 0
        cpu.f_h = cpu.a & 0xF < cpu.memory_at_hl & 0xF
        cpu.f_c = cpu.a < cpu.memory_at_hl
        cpu.f_n = true
        return 8
      },
      # 0xBF CP A,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a &- cpu.a == 0
        cpu.f_h = cpu.a & 0xF < cpu.a & 0xF
        cpu.f_c = cpu.a < cpu.a
        cpu.f_n = true
        return 4
      },
      # 0xC0 RET NZ
      ->(cpu : CPU) {
        cpu.inc_pc
        if cpu.f_nz
          cpu.memory.tick_components
          cpu.pc = cpu.memory.read_word cpu.sp
          cpu.sp += 2
          return 20
        end
        return 8
      },
      # 0xC1 POP BC
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.bc = cpu.memory.read_word (cpu.sp += 2) - 2
        return 12
      },
      # 0xC2 JP NZ,u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        if cpu.f_nz
          cpu.pc = u16
          return 16
        end
        return 12
      },
      # 0xC3 JP u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        cpu.pc = u16
        return 16
      },
      # 0xC4 CALL NZ,u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        if cpu.f_nz
          cpu.memory.tick_components
          cpu.memory[cpu.sp -= 2] = cpu.pc
          cpu.pc = u16
          return 24
        end
        return 12
      },
      # 0xC5 PUSH BC
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.bc
        return 16
      },
      # 0xC6 ADD A,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.f_h = (cpu.a & 0x0F) + (u8 & 0x0F) > 0x0F
        cpu.a &+= u8
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < u8
        cpu.f_n = false
        return 8
      },
      # 0xC7 RST 00h
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.pc
        cpu.pc = 0x00_u16
        return 16
      },
      # 0xC8 RET Z
      ->(cpu : CPU) {
        cpu.inc_pc
        if cpu.f_z
          cpu.memory.tick_components
          cpu.pc = cpu.memory.read_word cpu.sp
          cpu.sp += 2
          return 20
        end
        return 8
      },
      # 0xC9 RET
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.pc = cpu.memory.read_word cpu.sp
        cpu.sp += 2
        return 16
      },
      # 0xCA JP Z,u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        if cpu.f_z
          cpu.pc = u16
          return 16
        end
        return 12
      },
      # 0xCB PREFIX CB
      ->(cpu : CPU) {
        cpu.inc_pc
        # todo: This should operate as a seperate instruction, but can't be interrupted.
        #       This will require a restructure where the CPU leads the timing, rather than the PPU.
        #       https://discordapp.com/channels/465585922579103744/465586075830845475/712358911151177818
        #       https://discordapp.com/channels/465585922579103744/465586075830845475/712359253255520328
        cycles = Opcodes::PREFIXED[cpu.memory[cpu.pc]].call cpu
        return cycles
        return 4
      },
      # 0xCC CALL Z,u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        if cpu.f_z
          cpu.memory.tick_components
          cpu.memory[cpu.sp -= 2] = cpu.pc
          cpu.pc = u16
          return 24
        end
        return 12
      },
      # 0xCD CALL u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.pc
        cpu.pc = u16
        return 24
      },
      # 0xCE ADC A,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        carry = cpu.f_c ? 0x01 : 0x00
        cpu.f_h = (cpu.a & 0x0F) + (u8 & 0x0F) + carry > 0x0F
        cpu.a &+= u8 &+ carry
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a < u8.to_u16 + carry
        cpu.f_n = false
        return 8
      },
      # 0xCF RST 08h
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.pc
        cpu.pc = 0x08_u16
        return 16
      },
      # 0xD0 RET NC
      ->(cpu : CPU) {
        cpu.inc_pc
        if cpu.f_nc
          cpu.memory.tick_components
          cpu.pc = cpu.memory.read_word cpu.sp
          cpu.sp += 2
          return 20
        end
        return 8
      },
      # 0xD1 POP DE
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.de = cpu.memory.read_word (cpu.sp += 2) - 2
        return 12
      },
      # 0xD2 JP NC,u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        if cpu.f_nc
          cpu.pc = u16
          return 16
        end
        return 12
      },
      # 0xD3 UNUSED
      ->(cpu : CPU) {
        cpu.inc_pc
        # unused opcode
        return 0
      },
      # 0xD4 CALL NC,u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        if cpu.f_nc
          cpu.memory.tick_components
          cpu.memory[cpu.sp -= 2] = cpu.pc
          cpu.pc = u16
          return 24
        end
        return 12
      },
      # 0xD5 PUSH DE
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.de
        return 16
      },
      # 0xD6 SUB A,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.f_h = cpu.a & 0x0F < u8 & 0x0F
        cpu.f_c = cpu.a < u8
        cpu.a &-= u8
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 8
      },
      # 0xD7 RST 10h
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.pc
        cpu.pc = 0x10_u16
        return 16
      },
      # 0xD8 RET C
      ->(cpu : CPU) {
        cpu.inc_pc
        if cpu.f_c
          cpu.memory.tick_components
          cpu.pc = cpu.memory.read_word cpu.sp
          cpu.sp += 2
          return 20
        end
        return 8
      },
      # 0xD9 RETI
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.ime = true
        cpu.pc = cpu.memory.read_word cpu.sp
        cpu.sp += 0x02
        return 16
      },
      # 0xDA JP C,u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        if cpu.f_c
          cpu.pc = u16
          return 16
        end
        return 12
      },
      # 0xDB UNUSED
      ->(cpu : CPU) {
        cpu.inc_pc
        # unused opcode
        return 0
      },
      # 0xDC CALL C,u16
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        if cpu.f_c
          cpu.memory.tick_components
          cpu.memory[cpu.sp -= 2] = cpu.pc
          cpu.pc = u16
          return 24
        end
        return 12
      },
      # 0xDD UNUSED
      ->(cpu : CPU) {
        cpu.inc_pc
        # unused opcode
        return 0
      },
      # 0xDE SBC A,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        to_sub = u8.to_u16 + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_h = (cpu.a & 0x0F) < (u8 & 0x0F) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_c = cpu.a < to_sub
        cpu.a &-= to_sub
        cpu.f_z = cpu.a == 0
        cpu.f_n = true
        return 8
      },
      # 0xDF RST 18h
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.pc
        cpu.pc = 0x18_u16
        return 16
      },
      # 0xE0 LD (FF00+u8),A
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.memory[0xFF00 &+ u8] = cpu.a
        return 12
      },
      # 0xE1 POP HL
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.hl = cpu.memory.read_word (cpu.sp += 2) - 2
        return 12
      },
      # 0xE2 LD (FF00+C),A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory[0xFF00 &+ cpu.c] = cpu.a
        return 8
      },
      # 0xE3 UNUSED
      ->(cpu : CPU) {
        cpu.inc_pc
        # unused opcode
        return 0
      },
      # 0xE4 UNUSED
      ->(cpu : CPU) {
        cpu.inc_pc
        # unused opcode
        return 0
      },
      # 0xE5 PUSH HL
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.hl
        return 16
      },
      # 0xE6 AND A,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.a &= u8
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = true
        cpu.f_c = false
        return 8
      },
      # 0xE7 RST 20h
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.pc
        cpu.pc = 0x20_u16
        return 16
      },
      # 0xE8 ADD SP,i8
      ->(cpu : CPU) {
        cpu.inc_pc
        i8 = cpu.memory[cpu.pc].to_i8!
        cpu.inc_pc
        r = cpu.sp &+ i8
        cpu.f_h = (cpu.sp ^ i8 ^ r) & 0x0010 != 0
        cpu.f_c = (cpu.sp ^ i8 ^ r) & 0x0100 != 0
        cpu.sp = r
        cpu.f_z = false
        cpu.f_n = false
        return 16
      },
      # 0xE9 JP HL
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.pc = cpu.hl
        return 4
      },
      # 0xEA LD (u16),A
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        cpu.memory[u16] = cpu.a
        return 16
      },
      # 0xEB UNUSED
      ->(cpu : CPU) {
        cpu.inc_pc
        # unused opcode
        return 0
      },
      # 0xEC UNUSED
      ->(cpu : CPU) {
        cpu.inc_pc
        # unused opcode
        return 0
      },
      # 0xED UNUSED
      ->(cpu : CPU) {
        cpu.inc_pc
        # unused opcode
        return 0
      },
      # 0xEE XOR A,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.a ^= u8
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 8
      },
      # 0xEF RST 28h
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.pc
        cpu.pc = 0x28_u16
        return 16
      },
      # 0xF0 LD A,(FF00+u8)
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.a = cpu.memory[0xFF00 &+ u8]
        return 12
      },
      # 0xF1 POP AF
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.af = cpu.memory.read_word (cpu.sp += 2) - 2
        cpu.f_z = cpu.af & (0x1 << 7)
        cpu.f_n = cpu.af & (0x1 << 6)
        cpu.f_h = cpu.af & (0x1 << 5)
        cpu.f_c = cpu.af & (0x1 << 4)
        return 12
      },
      # 0xF2 LD A,(FF00+C)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = cpu.memory[0xFF00 &+ cpu.c]
        return 8
      },
      # 0xF3 DI
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.ime = false
        return 4
      },
      # 0xF4 UNUSED
      ->(cpu : CPU) {
        cpu.inc_pc
        # unused opcode
        return 0
      },
      # 0xF5 PUSH AF
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.af
        return 16
      },
      # 0xF6 OR A,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.a |= u8
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 8
      },
      # 0xF7 RST 30h
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.pc
        cpu.pc = 0x30_u16
        return 16
      },
      # 0xF8 LD HL,SP+i8
      ->(cpu : CPU) {
        cpu.inc_pc
        i8 = cpu.memory[cpu.pc].to_i8!
        cpu.inc_pc
        cpu.hl = cpu.sp &+ i8
        cpu.f_h = (cpu.sp ^ i8 ^ cpu.hl) & 0x0010 != 0
        cpu.f_c = (cpu.sp ^ i8 ^ cpu.hl) & 0x0100 != 0
        cpu.f_z = false
        cpu.f_n = false
        return 12
      },
      # 0xF9 LD SP,HL
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.sp = cpu.hl
        return 8
      },
      # 0xFA LD A,(u16)
      ->(cpu : CPU) {
        cpu.inc_pc
        u16 = cpu.memory[cpu.pc].to_u16
        cpu.inc_pc
        u16 |= cpu.memory[cpu.pc].to_u16 << 8
        cpu.inc_pc
        cpu.a = cpu.memory[u16]
        return 16
      },
      # 0xFB EI
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.scheduler.schedule_gb(4, Proc(Nil).new { cpu.ime = true }, Scheduler::EventType::IME)
        return 4
      },
      # 0xFC UNUSED
      ->(cpu : CPU) {
        cpu.inc_pc
        # unused opcode
        return 0
      },
      # 0xFD UNUSED
      ->(cpu : CPU) {
        cpu.inc_pc
        # unused opcode
        return 0
      },
      # 0xFE CP A,u8
      ->(cpu : CPU) {
        cpu.inc_pc
        u8 = cpu.memory[cpu.pc]
        cpu.inc_pc
        cpu.f_z = cpu.a &- u8 == 0
        cpu.f_h = cpu.a & 0xF < u8 & 0xF
        cpu.f_c = cpu.a < u8
        cpu.f_n = true
        return 8
      },
      # 0xFF RST 38h
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory.tick_components
        cpu.memory[cpu.sp -= 2] = cpu.pc
        cpu.pc = 0x38_u16
        return 16
      },
    ]
    PREFIXED = [
      # 0x00 RLC B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b = (cpu.b << 1) + (cpu.b >> 7)
        cpu.f_z = cpu.b == 0
        cpu.f_c = cpu.b & 0x01
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x01 RLC C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c = (cpu.c << 1) + (cpu.c >> 7)
        cpu.f_z = cpu.c == 0
        cpu.f_c = cpu.c & 0x01
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x02 RLC D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d = (cpu.d << 1) + (cpu.d >> 7)
        cpu.f_z = cpu.d == 0
        cpu.f_c = cpu.d & 0x01
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x03 RLC E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e = (cpu.e << 1) + (cpu.e >> 7)
        cpu.f_z = cpu.e == 0
        cpu.f_c = cpu.e & 0x01
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x04 RLC H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h = (cpu.h << 1) + (cpu.h >> 7)
        cpu.f_z = cpu.h == 0
        cpu.f_c = cpu.h & 0x01
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x05 RLC L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l = (cpu.l << 1) + (cpu.l >> 7)
        cpu.f_z = cpu.l == 0
        cpu.f_c = cpu.l & 0x01
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x06 RLC (HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl = (cpu.memory_at_hl << 1) + (cpu.memory_at_hl >> 7)
        cpu.f_z = cpu.memory_at_hl == 0
        cpu.f_c = cpu.memory_at_hl & 0x01
        cpu.f_n = false
        cpu.f_h = false
        return 16
      },
      # 0x07 RLC A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = (cpu.a << 1) + (cpu.a >> 7)
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a & 0x01
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x08 RRC B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b = (cpu.b >> 1) + (cpu.b << 7)
        cpu.f_z = cpu.b == 0
        cpu.f_c = cpu.b & 0x80
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x09 RRC C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c = (cpu.c >> 1) + (cpu.c << 7)
        cpu.f_z = cpu.c == 0
        cpu.f_c = cpu.c & 0x80
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x0A RRC D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d = (cpu.d >> 1) + (cpu.d << 7)
        cpu.f_z = cpu.d == 0
        cpu.f_c = cpu.d & 0x80
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x0B RRC E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e = (cpu.e >> 1) + (cpu.e << 7)
        cpu.f_z = cpu.e == 0
        cpu.f_c = cpu.e & 0x80
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x0C RRC H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h = (cpu.h >> 1) + (cpu.h << 7)
        cpu.f_z = cpu.h == 0
        cpu.f_c = cpu.h & 0x80
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x0D RRC L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l = (cpu.l >> 1) + (cpu.l << 7)
        cpu.f_z = cpu.l == 0
        cpu.f_c = cpu.l & 0x80
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x0E RRC (HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl = (cpu.memory_at_hl >> 1) + (cpu.memory_at_hl << 7)
        cpu.f_z = cpu.memory_at_hl == 0
        cpu.f_c = cpu.memory_at_hl & 0x80
        cpu.f_n = false
        cpu.f_h = false
        return 16
      },
      # 0x0F RRC A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = (cpu.a >> 1) + (cpu.a << 7)
        cpu.f_z = cpu.a == 0
        cpu.f_c = cpu.a & 0x80
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x10 RL B
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.b & 0x80
        cpu.b = (cpu.b << 1) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_z = cpu.b == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x11 RL C
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.c & 0x80
        cpu.c = (cpu.c << 1) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_z = cpu.c == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x12 RL D
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.d & 0x80
        cpu.d = (cpu.d << 1) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_z = cpu.d == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x13 RL E
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.e & 0x80
        cpu.e = (cpu.e << 1) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_z = cpu.e == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x14 RL H
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.h & 0x80
        cpu.h = (cpu.h << 1) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_z = cpu.h == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x15 RL L
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.l & 0x80
        cpu.l = (cpu.l << 1) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_z = cpu.l == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x16 RL (HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.memory_at_hl & 0x80
        cpu.memory_at_hl = (cpu.memory_at_hl << 1) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_z = cpu.memory_at_hl == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 16
      },
      # 0x17 RL A
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.a & 0x80
        cpu.a = (cpu.a << 1) + (cpu.f_c ? 0x01 : 0x00)
        cpu.f_z = cpu.a == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x18 RR B
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.b & 0x01
        cpu.b = (cpu.b >> 1) + (cpu.f_c ? 0x80 : 0x00)
        cpu.f_z = cpu.b == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x19 RR C
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.c & 0x01
        cpu.c = (cpu.c >> 1) + (cpu.f_c ? 0x80 : 0x00)
        cpu.f_z = cpu.c == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x1A RR D
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.d & 0x01
        cpu.d = (cpu.d >> 1) + (cpu.f_c ? 0x80 : 0x00)
        cpu.f_z = cpu.d == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x1B RR E
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.e & 0x01
        cpu.e = (cpu.e >> 1) + (cpu.f_c ? 0x80 : 0x00)
        cpu.f_z = cpu.e == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x1C RR H
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.h & 0x01
        cpu.h = (cpu.h >> 1) + (cpu.f_c ? 0x80 : 0x00)
        cpu.f_z = cpu.h == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x1D RR L
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.l & 0x01
        cpu.l = (cpu.l >> 1) + (cpu.f_c ? 0x80 : 0x00)
        cpu.f_z = cpu.l == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x1E RR (HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.memory_at_hl & 0x01
        cpu.memory_at_hl = (cpu.memory_at_hl >> 1) + (cpu.f_c ? 0x80 : 0x00)
        cpu.f_z = cpu.memory_at_hl == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 16
      },
      # 0x1F RR A
      ->(cpu : CPU) {
        cpu.inc_pc
        carry = cpu.a & 0x01
        cpu.a = (cpu.a >> 1) + (cpu.f_c ? 0x80 : 0x00)
        cpu.f_z = cpu.a == 0
        cpu.f_c = carry
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x20 SLA B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.b & 0x80
        cpu.b <<= 1
        cpu.f_z = cpu.b == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x21 SLA C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.c & 0x80
        cpu.c <<= 1
        cpu.f_z = cpu.c == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x22 SLA D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.d & 0x80
        cpu.d <<= 1
        cpu.f_z = cpu.d == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x23 SLA E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.e & 0x80
        cpu.e <<= 1
        cpu.f_z = cpu.e == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x24 SLA H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.h & 0x80
        cpu.h <<= 1
        cpu.f_z = cpu.h == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x25 SLA L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.l & 0x80
        cpu.l <<= 1
        cpu.f_z = cpu.l == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x26 SLA (HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.memory_at_hl & 0x80
        cpu.memory_at_hl <<= 1
        cpu.f_z = cpu.memory_at_hl == 0
        cpu.f_n = false
        cpu.f_h = false
        return 16
      },
      # 0x27 SLA A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.a & 0x80
        cpu.a <<= 1
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x28 SRA B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.b & 0x01
        cpu.b = (cpu.b >> 1) + (cpu.b & 0x80)
        cpu.f_z = cpu.b == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x29 SRA C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.c & 0x01
        cpu.c = (cpu.c >> 1) + (cpu.c & 0x80)
        cpu.f_z = cpu.c == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x2A SRA D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.d & 0x01
        cpu.d = (cpu.d >> 1) + (cpu.d & 0x80)
        cpu.f_z = cpu.d == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x2B SRA E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.e & 0x01
        cpu.e = (cpu.e >> 1) + (cpu.e & 0x80)
        cpu.f_z = cpu.e == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x2C SRA H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.h & 0x01
        cpu.h = (cpu.h >> 1) + (cpu.h & 0x80)
        cpu.f_z = cpu.h == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x2D SRA L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.l & 0x01
        cpu.l = (cpu.l >> 1) + (cpu.l & 0x80)
        cpu.f_z = cpu.l == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x2E SRA (HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.memory_at_hl & 0x01
        cpu.memory_at_hl = (cpu.memory_at_hl >> 1) + (cpu.memory_at_hl & 0x80)
        cpu.f_z = cpu.memory_at_hl == 0
        cpu.f_n = false
        cpu.f_h = false
        return 16
      },
      # 0x2F SRA A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.a & 0x01
        cpu.a = (cpu.a >> 1) + (cpu.a & 0x80)
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x30 SWAP B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b = (cpu.b << 4) + (cpu.b >> 4)
        cpu.f_z = cpu.b == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 8
      },
      # 0x31 SWAP C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c = (cpu.c << 4) + (cpu.c >> 4)
        cpu.f_z = cpu.c == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 8
      },
      # 0x32 SWAP D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d = (cpu.d << 4) + (cpu.d >> 4)
        cpu.f_z = cpu.d == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 8
      },
      # 0x33 SWAP E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e = (cpu.e << 4) + (cpu.e >> 4)
        cpu.f_z = cpu.e == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 8
      },
      # 0x34 SWAP H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h = (cpu.h << 4) + (cpu.h >> 4)
        cpu.f_z = cpu.h == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 8
      },
      # 0x35 SWAP L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l = (cpu.l << 4) + (cpu.l >> 4)
        cpu.f_z = cpu.l == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 8
      },
      # 0x36 SWAP (HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl = (cpu.memory_at_hl << 4) + (cpu.memory_at_hl >> 4)
        cpu.f_z = cpu.memory_at_hl == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 16
      },
      # 0x37 SWAP A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a = (cpu.a << 4) + (cpu.a >> 4)
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        cpu.f_c = false
        return 8
      },
      # 0x38 SRL B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.b & 0x1
        cpu.b >>= 1
        cpu.f_z = cpu.b == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x39 SRL C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.c & 0x1
        cpu.c >>= 1
        cpu.f_z = cpu.c == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x3A SRL D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.d & 0x1
        cpu.d >>= 1
        cpu.f_z = cpu.d == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x3B SRL E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.e & 0x1
        cpu.e >>= 1
        cpu.f_z = cpu.e == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x3C SRL H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.h & 0x1
        cpu.h >>= 1
        cpu.f_z = cpu.h == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x3D SRL L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.l & 0x1
        cpu.l >>= 1
        cpu.f_z = cpu.l == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x3E SRL (HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.memory_at_hl & 0x1
        cpu.memory_at_hl >>= 1
        cpu.f_z = cpu.memory_at_hl == 0
        cpu.f_n = false
        cpu.f_h = false
        return 16
      },
      # 0x3F SRL A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_c = cpu.a & 0x1
        cpu.a >>= 1
        cpu.f_z = cpu.a == 0
        cpu.f_n = false
        cpu.f_h = false
        return 8
      },
      # 0x40 BIT 0,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.b & (0x1 << 0) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x41 BIT 0,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.c & (0x1 << 0) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x42 BIT 0,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.d & (0x1 << 0) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x43 BIT 0,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.e & (0x1 << 0) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x44 BIT 0,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.h & (0x1 << 0) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x45 BIT 0,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.l & (0x1 << 0) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x46 BIT 0,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.memory_at_hl & (0x1 << 0) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 12
      },
      # 0x47 BIT 0,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a & (0x1 << 0) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x48 BIT 1,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.b & (0x1 << 1) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x49 BIT 1,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.c & (0x1 << 1) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x4A BIT 1,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.d & (0x1 << 1) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x4B BIT 1,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.e & (0x1 << 1) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x4C BIT 1,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.h & (0x1 << 1) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x4D BIT 1,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.l & (0x1 << 1) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x4E BIT 1,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.memory_at_hl & (0x1 << 1) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 12
      },
      # 0x4F BIT 1,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a & (0x1 << 1) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x50 BIT 2,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.b & (0x1 << 2) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x51 BIT 2,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.c & (0x1 << 2) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x52 BIT 2,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.d & (0x1 << 2) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x53 BIT 2,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.e & (0x1 << 2) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x54 BIT 2,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.h & (0x1 << 2) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x55 BIT 2,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.l & (0x1 << 2) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x56 BIT 2,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.memory_at_hl & (0x1 << 2) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 12
      },
      # 0x57 BIT 2,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a & (0x1 << 2) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x58 BIT 3,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.b & (0x1 << 3) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x59 BIT 3,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.c & (0x1 << 3) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x5A BIT 3,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.d & (0x1 << 3) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x5B BIT 3,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.e & (0x1 << 3) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x5C BIT 3,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.h & (0x1 << 3) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x5D BIT 3,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.l & (0x1 << 3) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x5E BIT 3,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.memory_at_hl & (0x1 << 3) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 12
      },
      # 0x5F BIT 3,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a & (0x1 << 3) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x60 BIT 4,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.b & (0x1 << 4) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x61 BIT 4,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.c & (0x1 << 4) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x62 BIT 4,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.d & (0x1 << 4) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x63 BIT 4,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.e & (0x1 << 4) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x64 BIT 4,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.h & (0x1 << 4) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x65 BIT 4,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.l & (0x1 << 4) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x66 BIT 4,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.memory_at_hl & (0x1 << 4) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 12
      },
      # 0x67 BIT 4,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a & (0x1 << 4) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x68 BIT 5,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.b & (0x1 << 5) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x69 BIT 5,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.c & (0x1 << 5) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x6A BIT 5,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.d & (0x1 << 5) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x6B BIT 5,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.e & (0x1 << 5) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x6C BIT 5,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.h & (0x1 << 5) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x6D BIT 5,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.l & (0x1 << 5) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x6E BIT 5,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.memory_at_hl & (0x1 << 5) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 12
      },
      # 0x6F BIT 5,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a & (0x1 << 5) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x70 BIT 6,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.b & (0x1 << 6) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x71 BIT 6,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.c & (0x1 << 6) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x72 BIT 6,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.d & (0x1 << 6) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x73 BIT 6,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.e & (0x1 << 6) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x74 BIT 6,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.h & (0x1 << 6) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x75 BIT 6,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.l & (0x1 << 6) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x76 BIT 6,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.memory_at_hl & (0x1 << 6) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 12
      },
      # 0x77 BIT 6,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a & (0x1 << 6) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x78 BIT 7,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.b & (0x1 << 7) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x79 BIT 7,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.c & (0x1 << 7) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x7A BIT 7,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.d & (0x1 << 7) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x7B BIT 7,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.e & (0x1 << 7) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x7C BIT 7,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.h & (0x1 << 7) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x7D BIT 7,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.l & (0x1 << 7) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x7E BIT 7,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.memory_at_hl & (0x1 << 7) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 12
      },
      # 0x7F BIT 7,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.f_z = cpu.a & (0x1 << 7) == 0
        cpu.f_n = false
        cpu.f_h = true
        return 8
      },
      # 0x80 RES 0,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b &= ~(0x1 << 0)
        return 8
      },
      # 0x81 RES 0,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c &= ~(0x1 << 0)
        return 8
      },
      # 0x82 RES 0,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d &= ~(0x1 << 0)
        return 8
      },
      # 0x83 RES 0,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e &= ~(0x1 << 0)
        return 8
      },
      # 0x84 RES 0,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h &= ~(0x1 << 0)
        return 8
      },
      # 0x85 RES 0,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l &= ~(0x1 << 0)
        return 8
      },
      # 0x86 RES 0,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl &= ~(0x1 << 0)
        return 16
      },
      # 0x87 RES 0,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= ~(0x1 << 0)
        return 8
      },
      # 0x88 RES 1,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b &= ~(0x1 << 1)
        return 8
      },
      # 0x89 RES 1,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c &= ~(0x1 << 1)
        return 8
      },
      # 0x8A RES 1,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d &= ~(0x1 << 1)
        return 8
      },
      # 0x8B RES 1,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e &= ~(0x1 << 1)
        return 8
      },
      # 0x8C RES 1,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h &= ~(0x1 << 1)
        return 8
      },
      # 0x8D RES 1,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l &= ~(0x1 << 1)
        return 8
      },
      # 0x8E RES 1,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl &= ~(0x1 << 1)
        return 16
      },
      # 0x8F RES 1,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= ~(0x1 << 1)
        return 8
      },
      # 0x90 RES 2,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b &= ~(0x1 << 2)
        return 8
      },
      # 0x91 RES 2,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c &= ~(0x1 << 2)
        return 8
      },
      # 0x92 RES 2,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d &= ~(0x1 << 2)
        return 8
      },
      # 0x93 RES 2,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e &= ~(0x1 << 2)
        return 8
      },
      # 0x94 RES 2,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h &= ~(0x1 << 2)
        return 8
      },
      # 0x95 RES 2,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l &= ~(0x1 << 2)
        return 8
      },
      # 0x96 RES 2,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl &= ~(0x1 << 2)
        return 16
      },
      # 0x97 RES 2,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= ~(0x1 << 2)
        return 8
      },
      # 0x98 RES 3,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b &= ~(0x1 << 3)
        return 8
      },
      # 0x99 RES 3,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c &= ~(0x1 << 3)
        return 8
      },
      # 0x9A RES 3,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d &= ~(0x1 << 3)
        return 8
      },
      # 0x9B RES 3,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e &= ~(0x1 << 3)
        return 8
      },
      # 0x9C RES 3,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h &= ~(0x1 << 3)
        return 8
      },
      # 0x9D RES 3,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l &= ~(0x1 << 3)
        return 8
      },
      # 0x9E RES 3,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl &= ~(0x1 << 3)
        return 16
      },
      # 0x9F RES 3,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= ~(0x1 << 3)
        return 8
      },
      # 0xA0 RES 4,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b &= ~(0x1 << 4)
        return 8
      },
      # 0xA1 RES 4,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c &= ~(0x1 << 4)
        return 8
      },
      # 0xA2 RES 4,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d &= ~(0x1 << 4)
        return 8
      },
      # 0xA3 RES 4,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e &= ~(0x1 << 4)
        return 8
      },
      # 0xA4 RES 4,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h &= ~(0x1 << 4)
        return 8
      },
      # 0xA5 RES 4,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l &= ~(0x1 << 4)
        return 8
      },
      # 0xA6 RES 4,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl &= ~(0x1 << 4)
        return 16
      },
      # 0xA7 RES 4,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= ~(0x1 << 4)
        return 8
      },
      # 0xA8 RES 5,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b &= ~(0x1 << 5)
        return 8
      },
      # 0xA9 RES 5,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c &= ~(0x1 << 5)
        return 8
      },
      # 0xAA RES 5,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d &= ~(0x1 << 5)
        return 8
      },
      # 0xAB RES 5,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e &= ~(0x1 << 5)
        return 8
      },
      # 0xAC RES 5,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h &= ~(0x1 << 5)
        return 8
      },
      # 0xAD RES 5,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l &= ~(0x1 << 5)
        return 8
      },
      # 0xAE RES 5,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl &= ~(0x1 << 5)
        return 16
      },
      # 0xAF RES 5,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= ~(0x1 << 5)
        return 8
      },
      # 0xB0 RES 6,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b &= ~(0x1 << 6)
        return 8
      },
      # 0xB1 RES 6,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c &= ~(0x1 << 6)
        return 8
      },
      # 0xB2 RES 6,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d &= ~(0x1 << 6)
        return 8
      },
      # 0xB3 RES 6,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e &= ~(0x1 << 6)
        return 8
      },
      # 0xB4 RES 6,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h &= ~(0x1 << 6)
        return 8
      },
      # 0xB5 RES 6,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l &= ~(0x1 << 6)
        return 8
      },
      # 0xB6 RES 6,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl &= ~(0x1 << 6)
        return 16
      },
      # 0xB7 RES 6,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= ~(0x1 << 6)
        return 8
      },
      # 0xB8 RES 7,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b &= ~(0x1 << 7)
        return 8
      },
      # 0xB9 RES 7,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c &= ~(0x1 << 7)
        return 8
      },
      # 0xBA RES 7,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d &= ~(0x1 << 7)
        return 8
      },
      # 0xBB RES 7,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e &= ~(0x1 << 7)
        return 8
      },
      # 0xBC RES 7,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h &= ~(0x1 << 7)
        return 8
      },
      # 0xBD RES 7,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l &= ~(0x1 << 7)
        return 8
      },
      # 0xBE RES 7,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl &= ~(0x1 << 7)
        return 16
      },
      # 0xBF RES 7,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a &= ~(0x1 << 7)
        return 8
      },
      # 0xC0 SET 0,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b |= (0x1 << 0)
        return 8
      },
      # 0xC1 SET 0,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c |= (0x1 << 0)
        return 8
      },
      # 0xC2 SET 0,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d |= (0x1 << 0)
        return 8
      },
      # 0xC3 SET 0,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e |= (0x1 << 0)
        return 8
      },
      # 0xC4 SET 0,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h |= (0x1 << 0)
        return 8
      },
      # 0xC5 SET 0,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l |= (0x1 << 0)
        return 8
      },
      # 0xC6 SET 0,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl |= (0x1 << 0)
        return 16
      },
      # 0xC7 SET 0,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= (0x1 << 0)
        return 8
      },
      # 0xC8 SET 1,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b |= (0x1 << 1)
        return 8
      },
      # 0xC9 SET 1,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c |= (0x1 << 1)
        return 8
      },
      # 0xCA SET 1,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d |= (0x1 << 1)
        return 8
      },
      # 0xCB SET 1,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e |= (0x1 << 1)
        return 8
      },
      # 0xCC SET 1,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h |= (0x1 << 1)
        return 8
      },
      # 0xCD SET 1,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l |= (0x1 << 1)
        return 8
      },
      # 0xCE SET 1,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl |= (0x1 << 1)
        return 16
      },
      # 0xCF SET 1,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= (0x1 << 1)
        return 8
      },
      # 0xD0 SET 2,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b |= (0x1 << 2)
        return 8
      },
      # 0xD1 SET 2,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c |= (0x1 << 2)
        return 8
      },
      # 0xD2 SET 2,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d |= (0x1 << 2)
        return 8
      },
      # 0xD3 SET 2,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e |= (0x1 << 2)
        return 8
      },
      # 0xD4 SET 2,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h |= (0x1 << 2)
        return 8
      },
      # 0xD5 SET 2,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l |= (0x1 << 2)
        return 8
      },
      # 0xD6 SET 2,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl |= (0x1 << 2)
        return 16
      },
      # 0xD7 SET 2,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= (0x1 << 2)
        return 8
      },
      # 0xD8 SET 3,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b |= (0x1 << 3)
        return 8
      },
      # 0xD9 SET 3,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c |= (0x1 << 3)
        return 8
      },
      # 0xDA SET 3,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d |= (0x1 << 3)
        return 8
      },
      # 0xDB SET 3,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e |= (0x1 << 3)
        return 8
      },
      # 0xDC SET 3,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h |= (0x1 << 3)
        return 8
      },
      # 0xDD SET 3,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l |= (0x1 << 3)
        return 8
      },
      # 0xDE SET 3,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl |= (0x1 << 3)
        return 16
      },
      # 0xDF SET 3,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= (0x1 << 3)
        return 8
      },
      # 0xE0 SET 4,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b |= (0x1 << 4)
        return 8
      },
      # 0xE1 SET 4,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c |= (0x1 << 4)
        return 8
      },
      # 0xE2 SET 4,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d |= (0x1 << 4)
        return 8
      },
      # 0xE3 SET 4,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e |= (0x1 << 4)
        return 8
      },
      # 0xE4 SET 4,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h |= (0x1 << 4)
        return 8
      },
      # 0xE5 SET 4,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l |= (0x1 << 4)
        return 8
      },
      # 0xE6 SET 4,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl |= (0x1 << 4)
        return 16
      },
      # 0xE7 SET 4,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= (0x1 << 4)
        return 8
      },
      # 0xE8 SET 5,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b |= (0x1 << 5)
        return 8
      },
      # 0xE9 SET 5,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c |= (0x1 << 5)
        return 8
      },
      # 0xEA SET 5,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d |= (0x1 << 5)
        return 8
      },
      # 0xEB SET 5,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e |= (0x1 << 5)
        return 8
      },
      # 0xEC SET 5,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h |= (0x1 << 5)
        return 8
      },
      # 0xED SET 5,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l |= (0x1 << 5)
        return 8
      },
      # 0xEE SET 5,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl |= (0x1 << 5)
        return 16
      },
      # 0xEF SET 5,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= (0x1 << 5)
        return 8
      },
      # 0xF0 SET 6,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b |= (0x1 << 6)
        return 8
      },
      # 0xF1 SET 6,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c |= (0x1 << 6)
        return 8
      },
      # 0xF2 SET 6,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d |= (0x1 << 6)
        return 8
      },
      # 0xF3 SET 6,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e |= (0x1 << 6)
        return 8
      },
      # 0xF4 SET 6,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h |= (0x1 << 6)
        return 8
      },
      # 0xF5 SET 6,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l |= (0x1 << 6)
        return 8
      },
      # 0xF6 SET 6,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl |= (0x1 << 6)
        return 16
      },
      # 0xF7 SET 6,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= (0x1 << 6)
        return 8
      },
      # 0xF8 SET 7,B
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.b |= (0x1 << 7)
        return 8
      },
      # 0xF9 SET 7,C
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.c |= (0x1 << 7)
        return 8
      },
      # 0xFA SET 7,D
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.d |= (0x1 << 7)
        return 8
      },
      # 0xFB SET 7,E
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.e |= (0x1 << 7)
        return 8
      },
      # 0xFC SET 7,H
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.h |= (0x1 << 7)
        return 8
      },
      # 0xFD SET 7,L
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.l |= (0x1 << 7)
        return 8
      },
      # 0xFE SET 7,(HL)
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.memory_at_hl |= (0x1 << 7)
        return 16
      },
      # 0xFF SET 7,A
      ->(cpu : CPU) {
        cpu.inc_pc
        cpu.a |= (0x1 << 7)
        return 8
      },
    ]
  end
end
