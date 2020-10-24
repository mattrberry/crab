module THUMB
  def thumb_high_reg_branch_exchange(instr : Word) : Nil
    op = bits(instr, 8..9)
    h1 = bit?(instr, 7)
    h2 = bit?(instr, 6)
    rs = bits(instr, 3..5)
    rd = bits(instr, 0..2)

    rd += 8 if h1
    rs += 8 if h2

    case op
    when 0b00 then @r[rd] = add(@r[rd], @r[rs], true)
    when 0b01 then sub(@r[rd], @r[rs], true)
    when 0b10 then @r[rd] = @r[rs]
    when 0b11
      if bit?(@r[rs], 0)
        @r[15] = @r[rs] & ~1
      else
        @cpsr.thumb = false
        @r[15] = @r[rs] & ~3
      end
      clear_pipeline
    end
    clear_pipeline if rd == 15
  end
end
