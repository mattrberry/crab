require "yaml"

CONFIG_FILE_PATH = Path["~/.config/crab/"].expand(home: true)
CONFIG_FILE_NAME = "crab.yml"
CONFIG_FILE      = CONFIG_FILE_PATH / CONFIG_FILE_NAME

Dir.mkdir_p(CONFIG_FILE_PATH)
File.touch(CONFIG_FILE)

class Config
  include YAML::Serializable
  property explorer_dir : Path = Path[Dir.current]
  property keybindings : Hash(LibSDL::Keycode, Input) = {
    LibSDL::Keycode::E         => Input::UP,
    LibSDL::Keycode::D         => Input::DOWN,
    LibSDL::Keycode::S         => Input::LEFT,
    LibSDL::Keycode::F         => Input::RIGHT,
    LibSDL::Keycode::K         => Input::A,
    LibSDL::Keycode::J         => Input::B,
    LibSDL::Keycode::L         => Input::SELECT,
    LibSDL::Keycode::SEMICOLON => Input::START,
    LibSDL::Keycode::W         => Input::L,
    LibSDL::Keycode::R         => Input::R,
  }
  property recents : Array(String) = [] of String
  property run_bios : Bool = false
  property gba : GBA = GBA.new
  property gbc : GBC = GBC.new

  private class Args
    property headless : Bool = false
    property run_bios : Bool?
    property fifo : Bool?
  end

  @[YAML::Field(ignore: true)]
  getter args = Args.new

  def self.new : Config
    Config.from_yaml(File.read(CONFIG_FILE))
  end

  def commit : Nil
    File.write(CONFIG_FILE, to_yaml)
  end

  def run_bios : Bool
    unless (run_bios = args.run_bios).nil?
      run_bios
    else
      @run_bios
    end
  end

  class GBA
    include YAML::Serializable
    property bios : String?

    DEFAULT_BIOS = Path["#{__DIR__}/../../../bios.bin"].normalize

    def initialize
    end

    def bios : String
      @bios || DEFAULT_BIOS.to_s
    end
  end

  class GBC
    include YAML::Serializable
    property bios : String?
    property fifo : Bool = false

    def initialize
    end
  end
end
