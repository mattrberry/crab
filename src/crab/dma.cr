class DMA
  class DMACNT < BitField(UInt16)
    bool enable
    bool irq_enable
    num start_timing, 2
    bool game_pak
    num type, 1
    bool repeat
    num source_control, 2
    num dest_control, 2
    num not_used, 5

    def to_s(io)
      io << "enable:#{enable}, irq:#{irq_enable}, timing:#{start_timing}, game_pak:#{game_pak}, type:#{type}, repeat:#{repeat}, srcctl:#{source_control}, dstctl:#{dest_control}"
    end
  end

  def initialize(@gba : GBA)
    @dmasad = Array(UInt32).new 4, 0
    @dmadad = Array(UInt32).new 4, 0
    @dmacnt_l = Array(UInt16).new 4, 0
    @dmacnt_h = Array(DMACNT).new 4 { DMACNT.new 0 }
    @src = Array(UInt32).new 4, 0
    @dst = Array(UInt32).new 4, 0
    @src_mask = [0x07FFFFFF, 0x0FFFFFFF, 0x0FFFFFFF, 0x0FFFFFFF]
    @dst_mask = [0x07FFFFFF, 0x07FFFFFF, 0x07FFFFFF, 0x0FFFFFFF]
    @len_mask = [0x3FFF, 0x3FFF, 0x3FFF, 0xFFFF]
  end

  def read_io(io_addr : Int) : UInt8
    dma_number = (io_addr - 0xB0) // 12
    reg = (io_addr - 0xB0) % 12
    case reg
    when 0, 1, 2, 3 # dmasad
      (@dmasad[dma_number] >> 8 * reg).to_u8!
    when 4, 5, 6, 7 # dmadad
      (@dmadad[dma_number] >> 8 * (reg - 4)).to_u8!
    when 8, 9 # dmacnt_l
      (@dmacnt_l[dma_number] >> 8 * (reg - 8)).to_u8!
    when 10, 11 # dmacnt_h
      (@dmacnt_h[dma_number].value >> 8 * (reg - 10)).to_u8!
    else abort "Unmapped DMA read ~ addr:#{hex_str io_addr.to_u8}"
    end
  end

  def write_io(io_addr : Int, value : UInt8) : Nil
    dma_number = (io_addr - 0xB0) // 12
    reg = (io_addr - 0xB0) % 12
    case reg
    when 0, 1, 2, 3 # dmasad
      mask = 0xFF_u32 << (8 * reg)
      value = value.to_u32 << (8 * reg)
      dmasad = @dmasad[dma_number]
      @dmasad[dma_number] = ((dmasad & ~mask) | value) & @src_mask[dma_number]
    when 4, 5, 6, 7 # dmadad
      reg -= 4
      mask = 0xFF_u32 << (8 * reg)
      value = value.to_u32 << (8 * reg)
      dmadad = @dmadad[dma_number]
      @dmadad[dma_number] = ((dmadad & ~mask) | value) & @dst_mask[dma_number]
    when 8, 9 # dmacnt_l
      reg -= 8
      mask = 0xFF_u32 << (8 * reg)
      value = value.to_u16 << (8 * reg)
      dmacnt_l = @dmacnt_l[dma_number]
      @dmacnt_l[dma_number] = ((dmacnt_l & ~mask) | value) & @len_mask[dma_number]
    when 10, 11 # dmacnt_h
      reg -= 10
      mask = 0xFF_u32 << (8 * reg)
      value = value.to_u16 << (8 * reg)
      dmacnt_h = @dmacnt_h[dma_number]
      enabled = dmacnt_h.enable
      dmacnt_h.value = (dmacnt_h.value & ~mask) | value
      if dmacnt_h.enable && !enabled
        @src[dma_number], @dst[dma_number] = @dmasad[dma_number], @dmadad[dma_number]
        trigger dma_number, on_write: true
      end
    else abort "Unmapped DMA write ~ addr:#{hex_str io_addr.to_u8}, val:#{value}".colorize(:yellow)
    end
  end

  # todo: clean up _all_ of the trigger logic. this is nasty.
  # todo: vdma
  def trigger_hdma : Nil
    4.times do |channel|
      dmacnt_h = @dmacnt_h[channel]
      if dmacnt_h.start_timing == 2 && dmacnt_h.enable
        trigger channel
        dmacnt_h.enable = false unless dmacnt_h.repeat
      end
    end
  end

  def trigger(channel : Int, on_write = false) : Nil
    dmacnt_h = @dmacnt_h[channel]
    log "DMA channel ##{channel} enabled, #{hex_str @dmasad[channel]} -> #{hex_str @dmadad[channel]}, len: #{hex_str @dmacnt_l[channel]}"
    log "  DMACNT: #{dmacnt_h.to_s}"
    log "  TM#{@gba.apu.soundcnt_h.dma_sound_a_timer}CNT: #{@gba.timer.tmcnt[@gba.apu.soundcnt_h.dma_sound_a_timer]}"
    if dmacnt_h.start_timing == 0 || !on_write
      special = dmacnt_h.start_timing == 3
      fifo_dma = special && 1 <= channel <= 2
      delta = 2 << dmacnt_h.type # transfer either halfwords or words
      delta = 4 if fifo_dma      # fifo audio always transfers in words
      ds = delta * case dmacnt_h.source_control
      when 0 then 1
      when 1 then -1
      when 2 then 0
      when 3 then puts "Prohibited source control".colorize.fore(:red); 1
      else        abort "Impossible source control: #{dmacnt_h.source_control}"
      end
      dd = delta * case dmacnt_h.dest_control
      when 0 then 1
      when 1 then -1
      when 2 then 0
      when 3 then 1
      else        abort "Impossible source control: #{dmacnt_h.dest_control}"
      end
      dd = 0 if fifo_dma # fifo audio doesn't increment destination
      len = @dmacnt_l[channel]
      len = 4 if fifo_dma
      log "  Starting transfer of #{len} #{"half" if dmacnt_h.type == 0}words from #{hex_str @src[channel]} to #{hex_str @dst[channel]}"
      len.times do |idx|
        log "transferring #{dmacnt_h.type == 0 ? "16" : "32"} bits from #{hex_str @src[channel]} to #{hex_str @dst[channel]}"
        @gba.bus[@dst[channel]] = !fifo_dma && dmacnt_h.type == 0 ? @gba.bus.read_half(@src[channel]).to_u16! : @gba.bus.read_word(@src[channel])
        @src[channel] += ds
        @dst[channel] += dd
      end
      @dst[channel] = @dmadad[channel] if dmacnt_h.dest_control == 3
      dmacnt_h.enable = false unless dmacnt_h.repeat
    end
  end
end
