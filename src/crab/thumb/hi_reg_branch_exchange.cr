module THUMB
  macro thumb_high_reg_branch_exchange
    ->(gba : GBA, instr : Word) {
    op = bits(instr, 8..9)
    h1 = bit?(instr, 7)
    h2 = bit?(instr, 6)
    rs = bits(instr, 3..5)
    rd = bits(instr, 0..2)

    rd += 8 if h1
    rs += 8 if h2

    # In this group only CMP (Op = 01) sets the CPSR condition codes.
    case op
    when 0b00 then gba.cpu.set_reg(rd, gba.cpu.add(gba.cpu.r[rd], gba.cpu.r[rs], false))
    when 0b01 then gba.cpu.sub(gba.cpu.r[rd], gba.cpu.r[rs], true)
    when 0b10 then gba.cpu.set_reg(rd, gba.cpu.r[rs])
    when 0b11
      if bit?(gba.cpu.r[rs], 0)
        gba.cpu.set_reg(15, gba.cpu.r[rs])
      else
        gba.cpu.cpsr.thumb = false
        gba.cpu.set_reg(15, gba.cpu.r[rs])
      end
    end
  }
  end
end
