class GBController < Controller
  getter emu : GB::GB
  class_getter extensions : Array(String) = ["gb", "gbc"]
  class_getter vertex_shader : String = "identity.vert"
  class_getter fragment_shader : String = "gb_colors.frag"

  getter width : Int32 = 160
  getter height : Int32 = 144

  def initialize(config : Config, bios : String?, rom : String)
    fifo = if config.args.fifo.nil?
             config.gbc.fifo
           else
             config.args.fifo.not_nil!
           end
    @emu = GB::GB.new(bios || config.gbc.bios, rom, fifo, config.args.headless, config.run_bios)
    @emu.post_init
  end

  # Audio

  def sync? : Bool
    @emu.apu.sync
  end
end
