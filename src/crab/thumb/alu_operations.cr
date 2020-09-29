module THUMB
  def thumb_alu_operations(instr : Word) : Nil
    op = bits(instr, 6..9)
    rs = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    # todo handle flags for all ops
    case op
    when 0b0000 then res = @r[rd] = @r[rd] & @r[rs]
    when 0b0001 then res = @r[rd] = @r[rd] ^ @r[rs]
    when 0b0010 then res = @r[rd] = lsl(@r[rd], @r[rs], true)
    when 0b0011 then res = @r[rd] = lsr(@r[rd], @r[rs], true)
    when 0b0100 then res = @r[rd] = asr(@r[rd], @r[rs], true)
    when 0b0101 then res = @r[rd] = @r[rd] &+ @r[rs] &+ @cpsr.carry.to_unsafe
    when 0b0110 then res = @r[rd] = @r[rd] &- @r[rs] &- ~@cpsr.carry.to_unsafe
    when 0b0111 then res = @r[rd] = ror(@r[rd], @r[rs], true)
    when 0b1000 then res = @r[rd] & @r[rs]
    when 0b1001 then res = @r[rd] = (-@r[rs].to_i32!).to_u32!
    when 0b1010 then res = sub(@r[rd], @r[rs], true)
    when 0b1011 then res = add(@r[rd], @r[rs], true)
    when 0b1100 then res = @r[rd] = @r[rd] | @r[rs]
    when 0b1101 then res = @r[rd] = @r[rs] * @r[rd]
    when 0b1110 then res = @r[rd] = @r[rd] & ~@r[rs]
    when 0b1111 then res = @r[rd] = ~@r[rs]
    else             raise "Invalid alu op: #{op}"
    end
    @cpsr.zero = res == 0
    @cpsr.negative = bit?(res, 31)
  end
end
