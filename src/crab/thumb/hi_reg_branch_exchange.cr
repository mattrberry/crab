module THUMB
  def thumb_high_reg_branch_exchange(instr : Word) : Nil
    op = bits(instr, 8..9)
    h1 = bit?(instr, 7)
    h2 = bit?(instr, 6)
    rs = bits(instr, 3..5)
    rd = bits(instr, 0..2)

    rd += 8 if h1
    rs += 8 if h2

    # In this group only CMP (Op = 01) sets the CPSR condition codes.
    case op
    when 0b00 then set_reg(rd, add(@r[rd], @r[rs], false))
    when 0b01 then sub(@r[rd], @r[rs], true)
    when 0b10 then set_reg(rd, @r[rs])
    when 0b11
      if bit?(@r[rs], 0)
        set_reg(15, @r[rs])
      else
        @cpsr.thumb = false
        set_reg(15, @r[rs])
      end
    end
  end
end
