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
  property gba : GBA = GBA.new
  property gbc : GBC = GBC.new

  def self.new : Config
    Config.from_yaml(File.read(CONFIG_FILE))
  end

  def commit : Nil
    File.write(CONFIG_FILE, to_yaml)
  end

  class GBA
    include YAML::Serializable
    property bios : String = "bios.bin"

    def initialize
    end
  end

  class GBC
    include YAML::Serializable
    property bios : String?

    def initialize
    end
  end
end
