require "./spec_helper"

describe GB::Memory do
  it "can't write over rom" do
    bytes = Array.new 0x8000, 0
    bytes[0] = 0x01
    bytes[1] = 0x02
    bytes[2] = 0x03
    memory = new_memory bytes
    memory[0x0000] = 0x05_u8
    memory[0x0001] = 0x06_u8
    memory[0x3FFF] = 0x07_u8
    memory[0x4000] = 0x07_u8
    memory[0x7FFF] = 0x08_u8

    memory[0x0000].should eq 0x01
    memory[0x0001].should eq 0x02
    memory[0x0002].should eq 0x03
    memory[0x3FFF].should eq 0x00
    memory[0x4000].should eq 0x00
    memory[0x7FFF].should eq 0x00
  end

  it "writes to external ram simple" do
    memory = new_memory [0x00]
    memory[0xA000] = 0x12.to_u8
    memory[0xBFFF] = 0x34.to_u8
    memory[0xA000].should eq 0x12
    memory[0xBFFF].should eq 0x34
  end
end
