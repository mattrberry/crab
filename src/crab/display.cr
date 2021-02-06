require "lib_gl"

class Display
  WIDTH  = 240
  HEIGHT = 160
  SCALE  =   4
  @fps = 30
  @seconds : Int32 = Time.utc.second

  def initialize
    @window = SDL::Window.new(window_title, WIDTH * SCALE, HEIGHT * SCALE, flags: SDL::Window::Flags::OPENGL)
    setup_gl
  end

  def draw(framebuffer : Slice(UInt16)) : Nil
    LibGL.tex_image_2d(LibGL::TEXTURE_2D, 0, LibGL::RGB5, 240, 160, 0, LibGL::RGBA, LibGL::UNSIGNED_SHORT_1_5_5_5_REV, framebuffer)
    LibGL.draw_arrays(LibGL::TRIANGLE_STRIP, 0, 4)
    LibSDL.gl_swap_window(@window)

    @fps += 1
    if Time.utc.second != @seconds
      @window.title = window_title
      @fps = 0
      @seconds = Time.utc.second
    end
  end

  private def window_title : String
    "crab - #{@fps} fps"
  end

  private def compile_shader(source : String, type : UInt32) : UInt32
    source_ptr = source.to_unsafe
    shader = LibGL.create_shader(type)
    LibGL.shader_source(shader, 1, pointerof(source_ptr), nil)
    LibGL.compile_shader(shader)
    shader_compiled = 0
    LibGL.get_shader_iv(shader, LibGL::COMPILE_STATUS, pointerof(shader_compiled))
    if shader_compiled != LibGL::TRUE
      log_length = 0
      LibGL.get_shader_iv(shader, LibGL::INFO_LOG_LENGTH, pointerof(log_length))
      s = " " * log_length
      LibGL.get_shader_info_log(shader, log_length, pointerof(log_length), s) if log_length > 0
      abort "Error compiling shader: #{s}"
    end
    shader
  end

  private def setup_gl : Nil
    {% if flag?(:darwin) %}
      LibSDL.gl_set_attribute(LibSDL::GLattr::SDL_GL_CONTEXT_FLAGS, LibSDL::GLcontextFlag::FORWARD_COMPATIBLE_FLAG)
    {% end %}
    LibSDL.gl_set_attribute(LibSDL::GLattr::SDL_GL_CONTEXT_PROFILE_MASK, LibSDL::GLprofile::PROFILE_CORE)
    LibSDL.gl_set_attribute(LibSDL::GLattr::SDL_GL_CONTEXT_MAJOR_VERSION, 3)
    LibSDL.gl_set_attribute(LibSDL::GLattr::SDL_GL_CONTEXT_MINOR_VERSION, 3)

    {% unless flag?(:darwin) %}
      # todo: proper debug messages for mac
      LibGL.enable(LibGL::DEBUG_OUTPUT)
      LibGL.enable(LibGL::DEBUG_OUTPUT_SYNCHRONOUS)
      LibGL.debug_message_callback(->Display.callback, nil)
    {% end %}

    LibSDL.gl_create_context @window
    LibSDL.gl_set_swap_interval(0) # disable vsync
    shader_program = LibGL.create_program

    puts "OpenGL version: #{String.new(LibGL.get_string(LibGL::VERSION))}"
    puts "Shader language version: #{String.new(LibGL.get_string(LibGL::SHADING_LANGUAGE_VERSION))}"

    vert_shader_id = compile_shader(File.read("src/crab/shaders/gba_colors.vert"), LibGL::VERTEX_SHADER)
    frag_shader_id = compile_shader(File.read("src/crab/shaders/gba_colors.frag"), LibGL::FRAGMENT_SHADER)

    frame_buffer = 0_u32
    LibGL.gen_textures(1, pointerof(frame_buffer))
    LibGL.active_texture(LibGL::TEXTURE0)
    LibGL.bind_texture(LibGL::TEXTURE_2D, frame_buffer)
    LibGL.attach_shader(shader_program, vert_shader_id)
    LibGL.attach_shader(shader_program, frag_shader_id)
    LibGL.link_program(shader_program)
    LibGL.validate_program(shader_program)
    a = [LibGL::BLUE, LibGL::GREEN, LibGL::RED, LibGL::ONE] # flip the rgba to bgra where a is always 1
    a_ptr = pointerof(a).as(Int32*)
    LibGL.tex_parameter_iv(LibGL::TEXTURE_2D, LibGL::TEXTURE_SWIZZLE_RGBA, a_ptr)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MIN_FILTER, LibGL::NEAREST)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MAG_FILTER, LibGL::NEAREST)
    LibGL.use_program(shader_program)
    vao = 0_u32 # required even if not used in modern opengl
    LibGL.gen_vertex_arrays(1, pointerof(vao))
    LibGL.bind_vertex_array(vao)
  end

  protected def self.callback(source : UInt32, type : UInt32, id : UInt32, severity : UInt32, length : Int32, message : Pointer(UInt8), userParam : Pointer(Void)) : Nil
    puts "OpenGL debug message: #{String.new message}"
  end
end
