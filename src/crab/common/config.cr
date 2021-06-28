require "yaml"

CONFIG_FILE_PATH = Path["~/.config/crab/"].expand(home: true)
CONFIG_FILE_NAME = Path["crab.yml"]
CONFIG_FILE      = CONFIG_FILE_PATH / CONFIG_FILE_NAME

Dir.mkdir_p(CONFIG_FILE_PATH)
File.touch(CONFIG_FILE)

class Config
  include YAML::Serializable
  property explorer_dir : String?
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

private def write(& : Config ->)
  new_config = config
  yield new_config
  File.write(CONFIG_FILE, new_config.to_yaml)
end

def explorer_dir : String
  config.explorer_dir || Dir.current
end

def set_explorer_dir(dir : String) : Nil
  write { |config| config.explorer_dir = dir }
end

def gbc_bios : String
  config.gbc.try(&.bios) || "bios.bin"
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
