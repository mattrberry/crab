module ARM
  def arm_data_processing(instr : Word) : Nil
    imm_flag = bit?(instr, 25)
    opcode = bits(instr, 21..24)
    set_conditions = bit?(instr, 20)
    rn = bits(instr, 16..19)
    rd = bits(instr, 12..15)
    operand_2 = if imm_flag # Operand 2 is an immediate
                  immediate_offset bits(instr, 0..11), set_conditions
                else # Operand 2 is a register
                  rotate_register bits(instr, 0..11), set_conditions
                end
    # todo handle carry flag on all ops
    case opcode
    when 0x0 then res = @r[rd] = @r[rn] & operand_2
    when 0x1 then res = @r[rd] = @r[rn] ^ operand_2
    when 0x2 then res = @r[rd] = sub(@r[rn], operand_2, set_conditions)
    when 0x3 then res = @r[rd] = sub(operand_2, @r[rn], set_conditions)
    when 0x4 then res = @r[rd] = add(@r[rn], operand_2, set_conditions)
    when 0x5 then res = @r[rd] = adc(@r[rn], operand_2, set_conditions)
    when 0x6 then res = @r[rd] = sbc(@r[rn], operand_2, set_conditions)
    when 0x7 then res = @r[rd] = sbc(operand_2, @r[rn], set_conditions)
    when 0x8 then res = @r[rn] & operand_2
    when 0x9 then res = @r[rn] ^ operand_2
    when 0xA then res = sub(@r[rn], operand_2, set_conditions)
    when 0xB then res = add(@r[rn], operand_2, set_conditions)
    when 0xC then res = @r[rd] = @r[rn] | operand_2
    when 0xD then res = @r[rd] = operand_2
    when 0xE then res = @r[rd] = @r[rn] & ~operand_2
    when 0xF then res = @r[rd] = ~operand_2
    else          raise "Unimplemented execution of data processing opcode: #{hex_str opcode}"
    end
    if set_conditions # todo this only works for logical ops, not arithmetic
      @cpsr.zero = res == 0
      @cpsr.negative = bit?(res, 31)
    end
    clear_pipeline if rd == 15 # todo only do this when needed (not 0xA or 0xB)
  end
end
