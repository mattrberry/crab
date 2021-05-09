require "./spec_helper"

describe "util" do
  describe "array_to_uint8" do
    it "converts array to uint8" do
      res = array_to_uint8 [false, true, 0, 1, 0_u8, 1_u8, -0, -1]
      res.should eq 0b01010101_u8
    end
  end

  describe "array_to_uint16" do
    it "converts array to uint16" do
      res = array_to_uint16 [false, true, 0, 1, 0_u8, 1_u8, -0, -1, false, true, 0, 1, 0_u8, 1_u8, -0, -1]
      res.should eq 0b0101010101010101_u16
    end
  end
end
