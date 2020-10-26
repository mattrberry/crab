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
    if rd == 15 && set_conditions
      old_spsr = @spsr.value
      switch_mode CPU::Mode.from_value @spsr.mode
      @cpsr.value = old_spsr
      set_conditions = false
    end
    # todo handle carry flag on all ops
    case opcode
    when 0x0 then res = set_reg(rd, @r[rn] & operand_2)
    when 0x1 then res = set_reg(rd, @r[rn] ^ operand_2)
    when 0x2 then res = set_reg(rd, sub(@r[rn], operand_2, set_conditions))
    when 0x3 then res = set_reg(rd, sub(operand_2, @r[rn], set_conditions))
    when 0x4 then res = set_reg(rd, add(@r[rn], operand_2, set_conditions))
    when 0x5 then res = set_reg(rd, adc(@r[rn], operand_2, set_conditions))
    when 0x6 then res = set_reg(rd, sbc(@r[rn], operand_2, set_conditions))
    when 0x7 then res = set_reg(rd, sbc(operand_2, @r[rn], set_conditions))
    when 0x8 then res = @r[rn] & operand_2
    when 0x9 then res = @r[rn] ^ operand_2
    when 0xA then res = sub(@r[rn], operand_2, set_conditions)
    when 0xB then res = add(@r[rn], operand_2, set_conditions)
    when 0xC then res = set_reg(rd, @r[rn] | operand_2)
    when 0xD then res = set_reg(rd, operand_2)
    when 0xE then res = set_reg(rd, @r[rn] & ~operand_2)
    when 0xF then res = set_reg(rd, ~operand_2)
    else          raise "Unimplemented execution of data processing opcode: #{hex_str opcode}"
    end
    if set_conditions # todo this only works for logical ops, not arithmetic
      @cpsr.zero = res == 0
      @cpsr.negative = bit?(res, 31)
    end
  end
end
