module THUMB
  def thumb_load_store_sign_extended(instr : Word) : Nil
    hs = bits(instr, 10..11)
    ro = bits(instr, 6..8)
    rb = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    address = @r[rb] &+ @r[ro]
    case hs
    when 0b00 then @gba.bus[address] = @r[rd].to_u16!                      # strh
    when 0b01 then set_reg(rd, @gba.bus[address].to_i8!.to_u32)            # ldsb
    when 0b10 then set_reg(rd, @gba.bus.read_half(address))                # ldrh
    when 0b11 then set_reg(rd, @gba.bus.read_half(address).to_i16!.to_u32) # ldsh
    else           raise "Invalid load/store signed extended: #{hs}"
    end
  end
end
