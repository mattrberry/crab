module GB
  enum CartridgeType
    ROM                            = 0x00
    ROM_RAM                        = 0x08
    ROM_RAM_BATTERY                = 0x09
    MBC1                           = 0x01
    MBC1_RAM                       = 0x02
    MBC1_RAM_BATTERY               = 0x03
    MBC2                           = 0x05
    MBC2_BATTERY                   = 0x06
    MBC3_TIMER_BATTERY             = 0x0F
    MBC3_TIMER_RAM_BATTERY         = 0x10
    MBC3                           = 0x11
    MBC3_RAM                       = 0x12
    MBC3_RAM_BATTERY               = 0x13
    MBC5                           = 0x19
    MBC5_RAM                       = 0x1A
    MBC5_RAM_BATTERY               = 0x1B
    MBC5_RUMBLE                    = 0x1C
    MBC5_RUMBLE_RAM                = 0x1D
    MBC5_RUMBLE_RAM_BATTERY        = 0x1E
    MBC6                           = 0x20
    MBC7_SENSOR_RUMBLE_RAM_BATTERY = 0x22
    MMM01                          = 0x0B
    MMM01_RAM                      = 0x0C
    MMM01_RAM_BATTERY              = 0x0D
    POCKET_CAMERA                  = 0xFC
    BANDAI_TAMA5                   = 0xFD
    HuC3                           = 0xFE
    HuC1_RAM_BATTERY               = 0xFF

    def is_rom? : Bool
      to_s.starts_with? "ROM"
    end

    def is_mbc1? : Bool
      to_s.starts_with? "MBC1"
    end

    def is_mbc2? : Bool
      to_s.starts_with? "MBC2"
    end

    def is_mbc3? : Bool
      to_s.starts_with? "MBC3"
    end

    def is_mbc5? : Bool
      to_s.starts_with? "MBC5"
    end

    def has_ram? : Bool
      to_s.includes? "RAM"
    end

    def has_battery? : Bool
      to_s.includes? "BATTERY"
    end

    def has_timer? : Bool
      to_s.includes? "TIMER"
    end

    def has_rumble? : Bool
      to_s.includes? "RUMBLE"
    end
  end
end
