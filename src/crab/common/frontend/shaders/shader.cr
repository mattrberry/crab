require "lib_gl"

class Shader
  @id : UInt32

  def initialize(vertex_shader_path : String | Path, fragment_shader_path : String | Path)
    @id = LibGL.create_program
    vert_shader_id = compile_shader(File.read(vertex_shader_path), LibGL::VERTEX_SHADER)
    frag_shader_id = compile_shader(File.read(fragment_shader_path), LibGL::FRAGMENT_SHADER)
    LibGL.attach_shader(@id, vert_shader_id)
    LibGL.attach_shader(@id, frag_shader_id)
    LibGL.link_program(@id)
    LibGL.validate_program(@id)
  end

  def use : Nil
    LibGL.use_program(@id)
  end

  macro method_missing(call)
    {% if !call.name.stringify.ends_with?("=") %}
      {% raise "#{@type.name}.#{call.name.stringify.id} does not exist" %}
    {% elsif call.args.size != 1 %}
      {% raise "Call to #{@type.name}.#{call.name.stringify.id} must take one argument" %}
    {% end %}

    loc = LibGL.get_uniform_location(@id, {{ call.name.stringify[0..-2] }})

    case {{call.args[0]}}
    when Float then LibGL.uniform_1f(loc, {{call.args[0]}})
    when Int   then LibGL.uniform_1i(loc, {{call.args[0]}})
    when Bool  then LibGL.uniform_1i(loc, {{call.args[0]}}.to_unsafe)
    else       raise "Call to {{@type.name}}.{{call.name.stringify.id}}({{call.args[0]}}) must be of type (Float | Int | Bool)"
    end
  end

  private def compile_shader(source : String, type : LibGL::Enum) : UInt32
    source_ptr = source.to_unsafe
    shader = LibGL.create_shader(type)
    LibGL.shader_source(shader, 1, pointerof(source_ptr), nil)
    LibGL.compile_shader(shader)
    LibGL.get_shader_iv(shader, LibGL::COMPILE_STATUS, out shader_compiled)
    if shader_compiled != LibGL::TRUE
      LibGL.get_shader_iv(shader, LibGL::INFO_LOG_LENGTH, out log_length)
      s = " " * log_length
      LibGL.get_shader_info_log(shader, log_length, out _, s) if log_length > 0
      abort "Error compiling shader: #{s}"
    end
    shader
  end
end
