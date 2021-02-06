module THUMB
  macro thumb_load_store_sign_extended
    ->(gba : GBA, instr : Word) {
    hs = bits(instr, 10..11)
    ro = bits(instr, 6..8)
    rb = bits(instr, 3..5)
    rd = bits(instr, 0..2)
    address = gba.cpu.r[rb] &+ gba.cpu.r[ro]
    case hs
    when 0b00 then gba.bus[address] = gba.cpu.r[rd].to_u16!              # strh
    when 0b01 then gba.cpu.set_reg(rd, gba.bus[address].to_i8!.to_u32!)   # ldsb
    when 0b10 then gba.cpu.set_reg(rd, gba.bus.read_half_rotate(address)) # ldrh
    when 0b11 then gba.cpu.set_reg(rd, gba.bus.read_half_signed(address)) # ldsh
    else           raise "Invalid load/store signed extended: #{hs}"
    end
  }
  end
end
