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
  property gb : GB?

  class GBA
    include YAML::Serializable
    property bios : String?
  end

  class GB
    include YAML::Serializable
    property bios : String?
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

def explorer_dir : String
  config.explorer_dir || Dir.current
end

def set_explorer_dir(dir : String) : Nil
  write { |config| config.explorer_dir = dir }
end

def gba_bios : String
  config.gba.try(&.bios) || "bios.bin"
end
