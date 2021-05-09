describe Joypad do
  it "defaults to buttons not pressed" do
    joypad = Joypad.new
    joypad.read.should eq 0b00111111
  end

  it "toggles button select" do
    joypad = Joypad.new
    joypad.write 0b00011111
    joypad.read.should eq 0b00011111
    joypad.write 0b00111111
    joypad.read.should eq 0b00111111
  end

  it "toggles direction select" do
    joypad = Joypad.new
    joypad.write 0b00101111
    joypad.read.should eq 0b00101111
    joypad.write 0b00111111
    joypad.read.should eq 0b00111111
  end

  it "only allows writing to selection keys" do
    joypad = Joypad.new
    joypad.write 0b00000000
    joypad.read.should eq 0b00001111
    joypad.write 0b11111111
    joypad.read.should eq 0b00111111
  end

  it "sets correct bits for one key down" do
    joypad = Joypad.new
    joypad.down = true
    joypad.write 0b00100000
    joypad.read.should eq 0b00100111
  end

  it "sets correct bits for two different keys down" do
    joypad = Joypad.new
    joypad.down = true
    joypad.b = true
    joypad.write 0b00000000
    joypad.read.should eq 0b00000101
  end

  it "sets correct bits for two parallel keys down" do
    joypad = Joypad.new
    joypad.up = true
    joypad.select = true
    joypad.button_keys = true
    joypad.direction_keys = true
    joypad.read.should eq 0b00001011
  end
end
