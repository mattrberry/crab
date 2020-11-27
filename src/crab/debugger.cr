class Debugger
  getter breakpoints = [] of Word

  def initialize(@gba : GBA)
  end

  def break_on(addr : Word)
    {% if flag? :debugger %} breakpoints << addr {% end %}
  end

  def check_debug : Nil
    {% if flag? :debugger %} debug if breakpoints.includes? @gba.cpu.r[15] {% end %}
  end

  private def debug : Nil
    puts "#{"----- DEBUGGER -----".colorize.mode(:bold)} #{"`help` for list of commands".colorize.mode(:dim)}"
    @gba.cpu.print_state
    while true
      input = gets
      case input
      when .nil?, "exit", "continue" then break
      when "step", "next", "tick"
        @gba.cpu.tick
        @gba.cpu.print_state
      when "bios"  then less @gba.bus.bios.hexdump
      when "ewram" then less @gba.bus.wram_board.hexdump
      when "iwram" then less @gba.bus.wram_chip.hexdump
      when "pram"  then less @gba.ppu.pram.hexdump
      when "vram"  then less @gba.ppu.vram.hexdump
      when "oam"   then less @gba.ppu.oam.hexdump
      when "rom"   then less @gba.cartridge.rom.hexdump
      when "sram"  then less @gba.cartridge.sram.hexdump
      when "list"  then print_breakpoints
      when /(b|break) (0x\d+)/
        match = /(b|break) (0x\d+)/.match(input.not_nil!).not_nil!
        breakpoints << match[2].to_i(base: 16, prefix: true).to_u32
        print_breakpoints
      when "clear"
        breakpoints.clear
        print_breakpoints
      when /clear (0x\d+)/
        match = /clear (0x\d+)/.match(input.not_nil!).not_nil!
        breakpoints.delete(match[1].to_i(base: 16, prefix: true))
        print_breakpoints
      when /\[(0x\d+)\]$/, /\[(0x\d+)\], word/
        match = /\[(0x\d+)\]/.match(input.not_nil!).not_nil!
        puts hex_str @gba.bus.read_word(match[1].to_i(base: 16, prefix: true))
      when /\[(0x\d+)\], half/
        match = /\[(0x\d+)\]/.match(input.not_nil!).not_nil!
        puts hex_str @gba.bus.read_half(match[1].to_i(base: 16, prefix: true))
      when /\[(0x\d+)\], byte/
        match = /\[(0x\d+)\]/.match(input.not_nil!).not_nil!
        puts hex_str @gba.bus[match[1].to_i(base: 16, prefix: true)]
      else
        puts "Available commands:"
        puts "  Resume execution:"
        puts "    ^D"
        puts "    exit"
        puts "    continue"
        puts "  Stepping:"
        puts "    step"
        puts "    next"
        puts "    tick"
        puts "  Listing breakpoints:"
        puts "    list"
        puts "  Adding breakpoints:"
        puts "    b 0x08000000"
        puts "    break 0x08000000"
        puts "  Removing breakpoints:"
        puts "    clear"
        puts "    clear 0x1234"
        puts "  Memory regions:"
        puts "    bios"
        puts "    ewram"
        puts "    iwram"
        puts "    pram"
        puts "    vram"
        puts "    oam"
        puts "    rom"
        puts "    sram"
        puts "  Reading memory:"
        puts "    [0x1234]"
        puts "    [0x1234], word"
        puts "    [0x1234], half"
        puts "    [0x1234], byte"
      end
      puts
    end
  end

  private def less(string : String) : Nil
    file = File.new("/tmp/crab", "w")
    file.puts string
    system "less /tmp/crab"
    file.delete
  end

  private def print_breakpoints : Nil
    print "Breakpoints: "
    breakpoints.sort.each { |b| print "#{hex_str b}, " }
    puts
  end
end
