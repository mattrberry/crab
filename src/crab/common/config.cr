require "yaml"

CONFIG_FILE_PATH = Path["~/.config/crab/"].expand(home: true)
CONFIG_FILE_NAME = "crab.yml"
CONFIG_FILE      = CONFIG_FILE_PATH / CONFIG_FILE_NAME

Dir.mkdir_p(CONFIG_FILE_PATH)
File.touch(CONFIG_FILE)

class Config
  include YAML::Serializable
  property explorer_dir : String?
  property keybindings : Hash(LibSDL::Keycode, Input)?
  property recents : Array(String)?
  property gba : GBA?
  property gbc : GBC?

  class GBA
    include YAML::Serializable
    property bios : String?

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

private def config : Config
  Config.from_yaml(File.read(CONFIG_FILE))
end

private def write(& : Config ->)
  new_config = config
  yield new_config
  File.write(CONFIG_FILE, new_config.to_yaml)
end

private def write_gba(& : Config::GBA ->)
  new_gba = config.gba || Config::GBA.new
  yield new_gba
  write { |config| config.gba = new_gba }
end

private def write_gbc(& : Config::GBC ->)
  new_gbc = config.gbc || Config::GBC.new
  yield new_gbc
  write { |config| config.gbc = new_gbc }
end

def explorer_dir : String
  config.explorer_dir || Dir.current
end

def set_explorer_dir(dir : String) : Nil
  write { |config| config.explorer_dir = dir }
end

def keybindings : Hash(LibSDL::Keycode, Input)
  config.keybindings || {
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
end

def set_keybindings(keybindings : Hash(LibSDL::Keycode, Input)) : Nil
  write { |config| config.keybindings = keybindings }
end

def recents : Array(String)
  config.recents || [] of String
end

def set_recents(recents : Array(String)) : Nil
  write { |config| config.recents = recents }
end

def gbc_bios : String?
  config.gbc.try(&.bios)
end

def set_gbc_bios(bios : String) : Nil
  write_gbc { |gbc| gbc.bios = bios }
end

def gba_bios : String
  config.gba.try(&.bios) || "bios.bin"
end

def set_gba_bios(bios : String) : Nil
  write_gba { |gba| gba.bios = bios }
end
