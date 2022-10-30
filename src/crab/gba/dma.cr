module GBA
  class DMA
    enum StartTiming
      Immediate = 0
      VBlank    = 1
      HBlank    = 2
      Special   = 3
    end

    enum AddressControl
      Increment       = 0
      Decrement       = 1
      Fixed           = 2
      IncrementReload = 3

      def delta : Int
        case self
        in Increment, IncrementReload then 1
        in Decrement                  then -1
        in Fixed                      then 0
        end
      end
    end

    SRC_MASK = [0x07FFFFFF_u32, 0x0FFFFFFF_u32, 0x0FFFFFFF_u32, 0x0FFFFFFF_u32]
    DST_MASK = [0x07FFFFFF_u32, 0x07FFFFFF_u32, 0x07FFFFFF_u32, 0x0FFFFFFF_u32]
    LEN_MASK = [0x3FFF_u16, 0x3FFF_u16, 0x3FFF_u16, 0xFFFF_u16]

    getter dmacnt_l : Array(UInt16)

    @interrupt_flags : Array(Proc(Nil))

    def initialize(@gba : GBA)
      @dmasad = Array(UInt32).new 4, 0
      @dmadad = Array(UInt32).new 4, 0
      @dmacnt_l = Array(UInt16).new 4, 0
      @dmacnt_h = Array(Reg::DMACNT).new 4 { Reg::DMACNT.new 0 }
      @src = Array(UInt32).new 4, 0
      @dst = Array(UInt32).new 4, 0
      @interrupt_flags = [->{ @gba.interrupts.reg_if.dma0 = true }, ->{ @gba.interrupts.reg_if.dma1 = true },
                          ->{ @gba.interrupts.reg_if.dma2 = true }, ->{ @gba.interrupts.reg_if.dma3 = true }]
    end

    def [](io_addr : UInt32) : UInt8
      channel = (io_addr - 0xB0) // 12
      reg = (io_addr - 0xB0) % 12
      case reg
      when 8, 9 then 0_u8 # dmacnt_l write-only
      when 10, 11
        val = @dmacnt_h[channel].read_byte(io_addr & 1)
        val |= 0b1000 if io_addr == 0xDF && @dmacnt_h[3].game_pak # DMA3 only
        val
      else @gba.bus.read_open_bus_value(io_addr)
      end
    end

    def []=(io_addr : UInt32, value : UInt8) : Nil
      channel = (io_addr - 0xB0) // 12
      reg = (io_addr - 0xB0) % 12
      case reg
      when 0, 1, 2, 3 # dmasad
        mask = 0xFF_u32 << (8 * reg)
        value = value.to_u32 << (8 * reg)
        dmasad = @dmasad[channel]
        @dmasad[channel] = ((dmasad & ~mask) | value) & SRC_MASK[channel]
      when 4, 5, 6, 7 # dmadad
        reg -= 4
        mask = 0xFF_u32 << (8 * reg)
        value = value.to_u32 << (8 * reg)
        dmadad = @dmadad[channel]
        @dmadad[channel] = ((dmadad & ~mask) | value) & DST_MASK[channel]
      when 8, 9 # dmacnt_l
        reg -= 8
        mask = 0xFF_u32 << (8 * reg)
        value = value.to_u16 << (8 * reg)
        dmacnt_l = @dmacnt_l[channel]
        @dmacnt_l[channel] = ((dmacnt_l & ~mask) | value) & LEN_MASK[channel]
      when 10, 11 # dmacnt_h
        dmacnt_h = @dmacnt_h[channel]
        enabled = dmacnt_h.enable
        dmacnt_h.write_byte(io_addr & 1, value)
        if dmacnt_h.enable && !enabled
          @src[channel], @dst[channel] = @dmasad[channel], @dmadad[channel]
          trigger channel if dmacnt_h.start_timing == StartTiming::Immediate.value
        end
      else abort "Unmapped DMA write ~ addr:#{hex_str io_addr.to_u8}, val:#{value}".colorize(:yellow)
      end
    end

    def trigger_hdma : Nil
      4.times do |channel|
        dmacnt_h = @dmacnt_h[channel]
        trigger channel if dmacnt_h.enable && dmacnt_h.start_timing == StartTiming::HBlank.value
      end
    end

    def trigger_vdma : Nil
      4.times do |channel|
        dmacnt_h = @dmacnt_h[channel]
        trigger channel if dmacnt_h.enable && dmacnt_h.start_timing == StartTiming::VBlank.value
      end
    end

    # todo: maybe abstract these various triggers
    def trigger_fifo(fifo_channel : Int) : Nil
      dmacnt_h = @dmacnt_h[fifo_channel + 1]
      trigger fifo_channel + 1 if dmacnt_h.enable && dmacnt_h.start_timing == StartTiming::Special.value
    end

    def trigger(channel : Int) : Nil
      dmacnt_h = @dmacnt_h[channel]

      start_timing = StartTiming.from_value(dmacnt_h.start_timing)
      source_control = AddressControl.from_value(dmacnt_h.source_control)
      dest_control = AddressControl.from_value(dmacnt_h.dest_control)
      word_size = 2 << dmacnt_h.type # 2 or 4 bytes

      len = @dmacnt_l[channel]

      puts "Prohibited source address control".colorize.fore(:yellow) if source_control == AddressControl::IncrementReload

      if start_timing == StartTiming::Special
        if channel == 1 || channel == 2 # fifo
          len = 4
          word_size = 4
          dest_control = AddressControl::Fixed
        elsif channel == 3 # video capture
          puts "todo: video capture dma"
        else # prohibited
          puts "Prohibited special dma".colorize.fore(:yellow)
        end
      end

      delta_source = word_size * source_control.delta
      delta_dest = word_size * dest_control.delta

      len.times do
        @gba.bus[@dst[channel]] = word_size == 4 ? @gba.bus.read_word(@src[channel]) : @gba.bus.read_half(@src[channel])
        @src[channel] &+= delta_source
        @dst[channel] &+= delta_dest
      end

      @dst[channel] = @dmadad[channel] if dest_control == AddressControl::IncrementReload
      dmacnt_h.enable = false unless dmacnt_h.repeat && start_timing != StartTiming::Immediate
      if dmacnt_h.irq_enable
        @interrupt_flags[channel].call
        @gba.interrupts.schedule_interrupt_check
      end
    end
  end
end
