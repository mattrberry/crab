module ARM
  def arm_data_processing(instr : Word) : Nil
    # todo all resulting flags
    imm_flag = bit?(instr, 25)
    opcode = bits(instr, 21..24)
    set_conditions = bit?(instr, 20)
    rn = bits(instr, 16..19)
    rd = bits(instr, 12..15)
    operand_2 = if imm_flag # Operand 2 is an immediate
                  rotate = bits(instr, 8..11)
                  imm = bits(instr, 0..7)
                  ror(imm, 2 * rotate)
                else # Operand 2 is a register
                  rotate_register bits(instr, 0..11)
                end
    case opcode
    when 0x0 then @r[rd] = rn & operand_2
    when 0x1 then @r[rd] = rn ^ operand_2
    when 0x2 then @r[rd] = rn &- operand_2
    when 0x3 then @r[rd] = operand_2 &- rn
    when 0x4 then @r[rd] = rn &+ operand_2
    when 0x5 then @r[rd] = rn &+ operand_2 &+ (bit?(@cpsr, 29) ? 1 : 0)
    when 0x6 then @r[rd] = rn &- operand_2 &+ (bit?(@cpsr, 29) ? 1 : 0) &- 1
    when 0x7 then @r[rd] = operand_2 &- rn &+ (bit?(@cpsr, 29) ? 1 : 0) &- 1
    when 0x8
    when 0x9
    when 0xA
    when 0xB
    when 0xC then @r[rd] = rn | operand_2
    when 0xD then @r[rd] = operand_2
    when 0xE then @r[rd] = rn & ~operand_2
    when 0xF then @r[rd] = ~operand_2
    else          raise "Unimplemented execution of data processing opcode: #{hex_str opcode}"
    end
  end
end
