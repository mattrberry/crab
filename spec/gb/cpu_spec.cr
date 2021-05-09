require "./spec_helper"

describe CPU do
  describe "registers" do
    it "do computations correctly across registers" do
      cpu = new_cpu [] of UInt8
      cpu.b = 0x00
      cpu.c = 0x00
      cpu.bc.should eq 0x0000
      cpu.c += 0x01
      cpu.b.should eq 0x00
      cpu.c.should eq 0x01
      cpu.bc.should eq 0x0001
      cpu.bc += 0x4320
      cpu.b.should eq 0x43
      cpu.c.should eq 0x21
      cpu.bc.should eq 0x4321
    end
  end

  describe "unprefixed opcode" do
    describe "0x00" do
      it "does nothing" do
        cpu = new_cpu [0x00]
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
      end
    end

    describe "0x01" do
      it "loads bc with d16" do
        d16 = 0x1234
        cpu = new_cpu [0x01, d16 & 0xFF, d16 >> 8]
        cpu.tick

        cpu.pc.should eq 3
        cpu.sp.should eq 0xFFFE
        cpu.bc.should eq d16
      end
    end

    describe "0x02" do
      it "loads (bc) with a" do
        cpu = new_cpu [0x02]
        cpu.a = 0x34
        cpu.bc = 0xA000
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.memory[0xA000].should eq 0x34
      end
    end

    describe "0x03" do
      it "increments bc" do
        cpu = new_cpu [0x03]
        cpu.bc = 0x1234
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.bc.should eq 0x1235
      end
    end

    describe "0x04" do
      it "increments b" do
        cpu = new_cpu [0x04]
        cpu.b = 0x12
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.b.should eq 0x13
      end
    end

    describe "0x05" do
      it "decrements b" do
        cpu = new_cpu [0x05]
        cpu.b = 0x12
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.b.should eq 0x11
      end
    end

    describe "0x06" do
      it "loads b with d8" do
        d8 = 0x12
        cpu = new_cpu [0x06, d8]
        cpu.tick

        cpu.pc.should eq 2
        cpu.sp.should eq 0xFFFE
        cpu.b.should eq d8
      end
    end

    describe "0x07" do
      it "rotates accumulator left w/o carry" do
        cpu = new_cpu [0x07]
        cpu.a = 0b01011010
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.a.should eq 0b10110100
        cpu.f_c.should eq false
      end

      it "rotates accumulator left w/ carry" do
        cpu = new_cpu [0x07]
        cpu.a = 0b10100101
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.a.should eq 0b01001011
        cpu.f_c.should eq true
      end
    end

    describe "0x08" do
      it "loads (d16) with sp" do
        d16 = 0xA000
        cpu = new_cpu [0x08, d16 & 0xFF, d16 >> 8]
        cpu.tick

        cpu.pc.should eq 3
        cpu.sp.should eq 0xFFFE
        cpu.memory[0xA000] = 0xFFFE
      end
    end

    describe "0x09" do
      it "adds bc to hl" do
        cpu = new_cpu [0x09]
        cpu.hl = 0x1010
        cpu.bc = 0x1111
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.hl.should eq 0x2121
        cpu.bc.should eq 0x1111
      end
    end

    describe "0x0A" do
      it "loads a with (bc)" do
        cpu = new_cpu [0x0A, 0x12]
        cpu.bc = 0x0001_u8
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.bc.should eq 0x0001
        cpu.memory[0x01].should eq 0x12
      end
    end

    describe "0x0B" do
      it "decrememnts bc" do
        cpu = new_cpu [0x0B]
        cpu.bc = 0x1234
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.bc.should eq 0x1233
      end
    end

    describe "0x0C" do
      it "increments c" do
        cpu = new_cpu [0x0C]
        cpu.c = 0x12
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.c.should eq 0x13
      end
    end

    describe "0x0D" do
      it "decrements c" do
        cpu = new_cpu [0x0D]
        cpu.c = 0x12
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.c.should eq 0x11
      end
    end

    describe "0x0E" do
      it "loads c with d8" do
        cpu = new_cpu [0x0E, 0x12]
        cpu.tick

        cpu.pc.should eq 2
        cpu.sp.should eq 0xFFFE
        cpu.c.should eq 0x12
      end
    end

    describe "0x0F" do
      it "rotates accumulator right w/o carry" do
        cpu = new_cpu [0x0F]
        cpu.a = 0b01011010
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.a.should eq 0b00101101
        cpu.f_c.should eq false
      end

      it "rotates accumulator right w/ carry" do
        cpu = new_cpu [0x0F]
        cpu.a = 0b10100101
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.a.should eq 0b11010010
        cpu.f_c.should eq true
      end
    end

    describe "0x10" do
      it "stops execution" do
        # todo: implement and test
      end
    end

    describe "0x11" do
      it "loads de with d16" do
        d16 = 0x1234
        cpu = new_cpu [0x11, d16 & 0xFF, d16 >> 8]
        cpu.tick

        cpu.pc.should eq 3
        cpu.sp.should eq 0xFFFE
        cpu.de.should eq d16
      end
    end

    describe "0x12" do
      it "loads (de) with a" do
        cpu = new_cpu [0x12]
        cpu.a = 0x34
        cpu.de = 0xA000
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.memory[0xA000].should eq 0x34
      end
    end

    describe "0x13" do
      it "increments de" do
        cpu = new_cpu [0x13]
        cpu.de = 0x1234
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.de.should eq 0x1235
      end
    end

    describe "0x14" do
      it "increments d" do
        cpu = new_cpu [0x14]
        cpu.d = 0x12
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.d.should eq 0x13
      end
    end

    describe "0x15" do
      it "decrements d" do
        cpu = new_cpu [0x15]
        cpu.d = 0x12
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.d.should eq 0x11
      end
    end

    describe "0x16" do
      it "loads d with d8" do
        d8 = 0x12
        cpu = new_cpu [0x16, d8]
        cpu.tick

        cpu.pc.should eq 2
        cpu.sp.should eq 0xFFFE
        cpu.d.should eq d8
      end
    end

    describe "0x17" do
      it "rotates accumulator left through carry w/o carry" do
        cpu = new_cpu [0x17]
        cpu.a = 0b01011010
        cpu.f_c = true
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.a.should eq 0b10110101
        cpu.f_c.should eq false
      end

      it "rotates accumulator left through carry w/ carry" do
        cpu = new_cpu [0x17]
        cpu.a = 0b10100101
        cpu.f_c = false
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.a.should eq 0b01001010
        cpu.f_c.should eq true
      end
    end

    # todo codes here

    describe "0x21" do
      it "loads hl with d16" do
        d16 = 0x1234
        cpu = new_cpu [0x21, d16 & 0xFF, d16 >> 8]
        cpu.tick

        cpu.pc.should eq 3
        cpu.sp.should eq 0xFFFE
        cpu.hl.should eq d16
      end
    end

    describe "0x22" do
      it "loads (hl+) with a" do
        cpu = new_cpu [0x22]
        cpu.a = 0x34
        cpu.hl = 0xA000
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.memory[0xA000].should eq 0x34
        cpu.hl.should eq 0xA001
      end
    end

    describe "0x23" do
      it "increments hl" do
        cpu = new_cpu [0x23]
        cpu.hl = 0x1234
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.hl.should eq 0x1235
      end
    end

    describe "0x24" do
      it "increments h" do
        cpu = new_cpu [0x24]
        cpu.h = 0x12
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.h.should eq 0x13
      end
    end

    describe "0x25" do
      it "decrements h" do
        cpu = new_cpu [0x25]
        cpu.h = 0x12
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.h.should eq 0x11
      end
    end

    describe "0x26" do
      it "loads h with d8" do
        d8 = 0x12
        cpu = new_cpu [0x26, d8]
        cpu.tick

        cpu.pc.should eq 2
        cpu.sp.should eq 0xFFFE
        cpu.h.should eq d8
      end
    end

    # todo codes here

    describe "0x31" do
      it "loads sp with d16" do
        d16 = 0x1234
        cpu = new_cpu [0x31, d16 & 0xFF, d16 >> 8]
        cpu.tick

        cpu.pc.should eq 3
        cpu.sp.should eq d16
      end
    end

    describe "0x32" do
      it "loads (hl-) with a" do
        cpu = new_cpu [0x32]
        cpu.a = 0x34
        cpu.hl = 0xA000
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.memory[0xA000].should eq 0x34
        cpu.hl.should eq 0x9FFF
      end
    end

    describe "0x33" do
      it "increments sp" do
        cpu = new_cpu [0x33]
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFF
      end
    end

    describe "0x34" do
      it "increments (hl)" do
        cpu = new_cpu [0x34]
        cpu.memory[0xA000] = 0x12_u8
        cpu.hl = 0xA000
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.memory[0xA000].should eq 0x13
      end
    end

    describe "0x35" do
      it "decrements (hl)" do
        cpu = new_cpu [0x35]
        cpu.memory[0xA000] = 0x12_u8
        cpu.hl = 0xA000
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
        cpu.memory[0xA000].should eq 0x11
      end
    end

    describe "0x36" do
      it "loads (hl) with d8" do
        d8 = 0x12
        cpu = new_cpu [0x36, d8]
        cpu.hl = 0xA000
        cpu.tick

        cpu.pc.should eq 2
        cpu.sp.should eq 0xFFFE
        cpu.memory[0xA000].should eq d8
      end
    end

    # todo codes here

    describe "0xC0" do
      it "returns if nz" do
        cpu = new_cpu [0xC0]
        cpu.sp = 0xFFF0_u16
        cpu.memory[0xFFF0] = 0x1234_u16
        cpu.f_z = false
        cpu.tick

        cpu.pc.should eq 0x1234
        cpu.sp.should eq 0xFFF2
      end

      it "doesn't return if not nz" do
        cpu = new_cpu [0xC0]
        cpu.f_z = true
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
      end
    end

    describe "0xC1" do
      it "pops bc" do
        cpu = new_cpu [0xC1]
        cpu.sp = 0xFFF0_u16
        cpu.memory[0xFFF0_u16] = 0x1234
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFF2
        cpu.bc.should eq 0x1234
      end
    end

    describe "0xC2" do
      it "jumps to a16 if nz" do
        a16 = 0xA000
        cpu = new_cpu [0xC2, a16 & 0xFF, a16 >> 8]
        cpu.f_z = false
        cpu.tick

        cpu.pc.should eq a16
        cpu.sp.should eq 0xFFFE
      end

      it "doesn't jump to a16 if not nz" do
        a16 = 0xA000
        cpu = new_cpu [0xC2, a16 & 0xFF, a16 >> 8]
        cpu.f_z = true
        cpu.tick

        cpu.pc.should eq 3
        cpu.sp.should eq 0xFFFE
      end
    end

    describe "0xC3" do
      it "jumps to a16" do
        a16 = 0xA000
        cpu = new_cpu [0xC3, a16 & 0xFF, a16 >> 8]
        cpu.tick

        cpu.pc.should eq 0xA000
        cpu.sp.should eq 0xFFFE
      end

      it "jumps to a16 regardless of nz" do
        a16 = 0xAC00
        cpu = new_cpu [0xC3, a16 & 0xFF, a16 >> 8]
        cpu.f_z = false
        cpu.tick
        cpu.pc.should eq a16
        cpu = new_cpu [0xC3, a16 & 0xFF, a16 >> 8]
        cpu.f_z = true
        cpu.tick
        cpu.pc.should eq a16
      end
    end

    describe "0xC4" do
      it "calls a16 if nz" do
        a16 = 0xAC00
        cpu = new_cpu [0xC4, a16 & 0xFF, a16 >> 8]
        cpu.f_z = false
        cpu.tick

        cpu.pc.should eq 0xAC00
        cpu.sp.should eq 0xFFFC
        cpu.memory[0xFFFD].should eq 0x00
        cpu.memory[0xFFFC].should eq 0x03
      end

      it "doesn't call a16 if not nz" do
        a16 = 0xAC00
        cpu = new_cpu [0xC4, a16 & 0xFF, a16 >> 8]
        cpu.f_z = true
        cpu.tick

        cpu.pc.should eq 3
        cpu.sp.should eq 0xFFFE
      end
    end

    describe "0xC5" do
      it "pushes bc" do
        cpu = new_cpu [0xC5]
        cpu.bc = 0x1234_u16
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFC
        cpu.memory[0xFFFD].should eq 0x12
        cpu.memory[0xFFFC].should eq 0x34
      end
    end

    describe "0xC6" do
      it "adds d8 to a" do
        d8 = 0x01
        cpu = new_cpu [0xC6, d8]
        cpu.a = 0xFF
        cpu.tick

        cpu.pc.should eq 2
        cpu.sp.should eq 0xFFFE
        cpu.a.should eq 0x00
        cpu.f_z.should eq true
        cpu.f_n.should eq false
        cpu.f_h.should eq true
        cpu.f_c.should eq true
      end
    end

    # todo codes here

    describe "0xD0" do
      it "returns if nc" do
        cpu = new_cpu [0xD0]
        cpu.sp = 0xFFF0_u16
        cpu.memory[0xFFF0] = 0x1234_u16
        cpu.f_c = false
        cpu.tick

        cpu.pc.should eq 0x1234
        cpu.sp.should eq 0xFFF2
      end

      it "doesn't return if not nc" do
        cpu = new_cpu [0xD0]
        cpu.f_c = true
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFE
      end
    end

    describe "0xD1" do
      it "pops de" do
        cpu = new_cpu [0xD1]
        cpu.sp = 0xFFF0_u16
        cpu.memory[0xFFF0_u16] = 0x1234
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFF2
        cpu.de.should eq 0x1234
      end
    end

    describe "0xD2" do
      it "jumps to a16 if nc" do
        a16 = 0xA000
        cpu = new_cpu [0xD2, a16 & 0xFF, a16 >> 8]
        cpu.f_c = false
        cpu.tick

        cpu.pc.should eq a16
        cpu.sp.should eq 0xFFFE
      end

      it "doesn't jump to a16 if not nc" do
        a16 = 0xA000
        cpu = new_cpu [0xD2, a16 & 0xFF, a16 >> 8]
        cpu.f_c = true
        cpu.tick

        cpu.pc.should eq 3
        cpu.sp.should eq 0xFFFE
      end
    end

    describe "0xD3" do
      # unused opcode
    end

    describe "0xD4" do
      it "calls a16 if nc" do
        a16 = 0xAC00
        cpu = new_cpu [0xD4, a16 & 0xFF, a16 >> 8]
        cpu.f_c = false
        cpu.tick

        cpu.pc.should eq 0xAC00
        cpu.sp.should eq 0xFFFC
        cpu.memory[0xFFFD].should eq 0x00
        cpu.memory[0xFFFC].should eq 0x03
      end

      it "doesn't call a16 if not nc" do
        a16 = 0xAC00
        cpu = new_cpu [0xD4, a16 & 0xFF, a16 >> 8]
        cpu.f_c = true
        cpu.tick

        cpu.pc.should eq 3
        cpu.sp.should eq 0xFFFE
      end
    end

    describe "0xD5" do
      it "pushes de" do
        cpu = new_cpu [0xD5]
        cpu.de = 0x1234_u16
        cpu.tick

        cpu.pc.should eq 1
        cpu.sp.should eq 0xFFFC
        cpu.memory[0xFFFD].should eq 0x12
        cpu.memory[0xFFFC].should eq 0x34
      end
    end

    describe "0xD6" do
      it "subs d8 from a" do
        d8 = 0x01
        cpu = new_cpu [0xD6, d8]
        cpu.a = 0x10
        cpu.tick

        cpu.pc.should eq 2
        cpu.sp.should eq 0xFFFE
        cpu.a.should eq 0x0F
        cpu.f_z.should eq false
        cpu.f_n.should eq true
        cpu.f_h.should eq true
        cpu.f_c.should eq false
      end
    end

    # todo codes here
  end

  describe "prefixed opcode" do
    # todo codes here

    describe "0x40" do
      it "tests bit 0 of b" do
        cpu = new_cpu [0xCB, 0x40]
        cpu.b = 0b01010101
        cpu.tick

        cpu.pc.should eq 2
        cpu.sp.should eq 0xFFFE
        cpu.b.should eq 0b01010101
        cpu.f_z.should eq false
        cpu.f_c.should eq false
        cpu.f_h.should eq true
      end
    end

    # todo codes here
  end
end
