require "./controllers/*"
require "./widgets/*"

class SDLOpenGLImGuiFrontend < Frontend
  CONTROLLERS    = [StubbedController, GBController, GBAController]
  ROM_EXTENSIONS = CONTROLLERS.reduce([] of String) { |acc, controller| acc + controller.extensions }
  SCALE          = 4
  SHADERS        = "src/crab/common/shaders"

  @controller : Controller

  @window : SDL::Window
  @gl_context : LibSDL::GLContext
  @io : ImGui::ImGuiIO
  @shader_program : UInt32?
  @frag_shader_id : UInt32?

  @shader_programs : Hash(Controller.class, UInt32)

  @microseconds = 0
  @frames = 0
  @last_time = Time.utc
  @seconds : Int32 = Time.utc.second

  @enable_blend = false
  @blending = false
  @enable_overlay = false
  @pause = false
  @recents : Array(String) = recents

  @opengl_info : OpenGLInfo

  def initialize(bios : String?, rom : String?)
    SDL.init(SDL::Init::VIDEO | SDL::Init::AUDIO | SDL::Init::JOYSTICK)
    LibSDL.joystick_open 0
    at_exit { SDL.quit }

    @controller = init_controller(bios, rom)
    @window = SDL::Window.new(
      window_title(59.7),
      @controller.window_width * SCALE,
      @controller.window_height * SCALE,
      x: LibSDL::WindowPosition::CENTERED,
      y: LibSDL::WindowPosition::CENTERED,
      flags: SDL::Window::Flags::OPENGL | SDL::Window::Flags::RESIZABLE
    )
    @gl_context = setup_gl
    @shader_programs = Hash.zip(CONTROLLERS, CONTROLLERS.map { |controller| create_shader_program(controller.shader) })
    LibGL.use_program(@shader_programs[@controller.class])
    @opengl_info = OpenGLInfo.new
    @io = setup_imgui
    LibSDL.gl_set_swap_interval(1) if @controller.class == StubbedController

    @file_explorer = ImGui::FileExplorer.new
    @keybindings = ImGui::Keybindings.new
  end

  def run : NoReturn
    loop do
      @controller.run_until_frame unless @pause
      handle_input
      LibGL.clear_color(0, 0, 0, 1)
      LibGL.clear(LibGL::COLOR_BUFFER_BIT)
      render_game
      render_imgui
      LibSDL.gl_swap_window(@window)
      update_draw_count
      handle_file_selection
    end
  end

  private def handle_file_selection : Nil
    if selection = @file_explorer.selection
      file, symbol = selection
      if symbol == :ROM
        load_new_rom(file.to_s)
      elsif symbol == :BIOS
        load_new_bios(file.to_s)
      else
        abort "Internal error: Unexpected file explorer symbol #{symbol}"
      end
    end
  end

  private def load_new_rom(rom : String?) : Nil
    LibSDL.close_audio(1)
    @controller = init_controller(nil, rom)
    @file_explorer.clear_selection

    @recents.delete(rom)
    @recents.insert(0, rom)
    @recents.pop(@recents.size - 8) if @recents.size > 8
    set_recents @recents

    LibSDL.set_window_size(@window, @controller.window_width * SCALE, @controller.window_height * SCALE)
    LibSDL.set_window_position(@window, LibSDL::WindowPosition::CENTERED, LibSDL::WindowPosition::CENTERED)
    LibGL.viewport(0, 0, @window.width, @window.height)
    LibGL.use_program(@shader_programs[@controller.class])

    LibSDL.gl_set_swap_interval(0)
    @enable_blend = false
    @blending = false
    @enable_overlay = false
    @pause = false
  end

  private def load_new_bios(bios : String) : Nil
    if @controller.class == GBController
      set_gbc_bios(bios)
    elsif @controller.class == GBAController
      set_gba_bios(bios)
    else
      abort "Internal error: Cannot set bios #{bios} for controller #{@controller}"
    end
    @file_explorer.clear_selection
  end

  private def handle_input : Nil
    while event = SDL::Event.poll
      ImGui::SDL2.process_event(event)
      case event
      when SDL::Event::Quit then exit
      when SDL::Event::JoyHat,
           SDL::Event::JoyButton then @controller.handle_controller_event(event)
      when SDL::Event::Keyboard
        if @keybindings.wants_input?
          @keybindings.key_released(event.sym) unless event.pressed? # pass on key release
        elsif input = @keybindings[event.sym]?
          @controller.handle_input(input, event.pressed?)
        elsif event.sym == LibSDL::Keycode::TAB
          @controller.toggle_sync if event.pressed?
        elsif event.sym == LibSDL::Keycode::Q && event.mod.includes?(LibSDL::Keymod::LCTRL)
          exit
        end
      else nil
      end
    end
  end

  private def toggle_blending : Nil
    if @blending
      LibGL.disable(LibGL::BLEND)
    else
      LibGL.enable(LibGL::BLEND)
    end
    @blending = @enable_blend = !@blending
  end

  private def render_game : Nil
    LibGL.tex_image_2d(
      LibGL::TEXTURE_2D,
      0,
      LibGL::RGB5,
      @controller.width,
      @controller.height,
      0,
      LibGL::RGBA,
      LibGL::UNSIGNED_SHORT_1_5_5_5_REV,
      @controller.get_framebuffer
    )
    LibGL.draw_arrays(LibGL::TRIANGLE_STRIP, 0, 4)
  end

  private def render_imgui : Nil
    ImGui::OpenGL3.new_frame
    ImGui::SDL2.new_frame(@window)
    ImGui.new_frame

    overlay_height = 10.0
    open_rom_selection = false
    open_bios_selection = false
    open_keybindings = false

    if (LibSDL.get_mouse_focus || @controller.class == StubbedController) && !@file_explorer.open? && !@keybindings.open?
      if ImGui.begin_main_menu_bar
        if ImGui.begin_menu "File"
          previously_paused = @pause

          open_rom_selection = ImGui.menu_item "Open ROM"
          open_bios_selection = ImGui.menu_item "Select BIOS" unless @controller.class == StubbedController
          if ImGui.begin_menu "Recent", @recents.size > 0
            @recents.each do |recent|
              load_new_rom(recent) if ImGui.menu_item recent
            end
            ImGui.separator
            if ImGui.menu_item "Clear"
              @recents.clear
              set_recents @recents
            end
            ImGui.end_menu
          end
          ImGui.separator
          ImGui.menu_item "Overlay", "", pointerof(@enable_overlay)
          # ImGui.menu_item "Blend", "", pointerof(@enable_blend) todo: re-implement blending now that frames are cleared
          ImGui.menu_item "Pause", "", pointerof(@pause)
          open_keybindings = ImGui.menu_item "Keybindings"
          ImGui.separator
          exit if ImGui.menu_item "Exit", "Ctrl+Q"
          ImGui.end_menu

          toggle_blending if @enable_blend ^ @blending
          LibSDL.gl_set_swap_interval(@pause.to_unsafe) if previously_paused ^ @pause
        end

        @controller.render_menu

        overlay_height += ImGui.get_window_size.y
        ImGui.end_main_menu_bar
      end
    end

    @file_explorer.render(:ROM, open_rom_selection, ROM_EXTENSIONS)
    @file_explorer.render(:BIOS, open_bios_selection)

    @keybindings.render(open_keybindings)

    if @enable_overlay
      ImGui.set_next_window_pos(ImGui::ImVec2.new 10, overlay_height)
      ImGui.set_next_window_bg_alpha(0.5)
      ImGui.begin("Overlay", pointerof(@enable_overlay),
        ImGui::ImGuiWindowFlags::NoDecoration | ImGui::ImGuiWindowFlags::NoMove |
        ImGui::ImGuiWindowFlags::NoSavedSettings)
      io_framerate = @io.framerate
      ImGui.text("FPS:        #{io_framerate.format(decimal_places: 1)}")
      ImGui.text("Frame time: #{(1000 / io_framerate).format(decimal_places: 3)}ms")
      ImGui.separator
      ImGui.text("OpenGL")
      ImGui.text("  Version: #{@opengl_info.version}")
      ImGui.text("  Shading: #{@opengl_info.shading}")
      ImGui.end
    end

    if @pause
      center = ImGui.get_main_viewport.get_center
      ImGui.set_next_window_pos(center, pivot: ImGui::ImVec2.new(0.5, 0.5))
      ImGui.begin("Pause", pointerof(@enable_overlay),
        ImGui::ImGuiWindowFlags::NoDecoration | ImGui::ImGuiWindowFlags::NoMove |
        ImGui::ImGuiWindowFlags::NoSavedSettings)
      ImGui.text("PAUSED")
      ImGui.end
    end

    @controller.render_windows

    ImGui.render
    ImGui::OpenGL3.render_draw_data(ImGui.get_draw_data)
  end

  private def window_title(fps : Float) : String
    "crab - #{fps.round(1)} fps"
  end

  private def update_draw_count : Nil
    current_time = Time.utc
    @microseconds += (current_time - @last_time).microseconds
    @last_time = current_time
    @frames += 1
    if current_time.second != @seconds
      fps = @frames * (1_000_000 / @microseconds)
      @window.title = window_title(fps)
      @microseconds = 0
      @frames = 0
      @seconds = current_time.second
    end
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

  private def setup_gl : LibSDL::GLContext
    {% if flag?(:darwin) %}
      LibSDL.gl_set_attribute(LibSDL::GLattr::SDL_GL_CONTEXT_FLAGS, LibSDL::GLcontextFlag::FORWARD_COMPATIBLE_FLAG)
    {% end %}
    LibSDL.gl_set_attribute(LibSDL::GLattr::SDL_GL_CONTEXT_PROFILE_MASK, LibSDL::GLprofile::PROFILE_CORE)
    LibSDL.gl_set_attribute(LibSDL::GLattr::SDL_GL_CONTEXT_MAJOR_VERSION, 3)
    LibSDL.gl_set_attribute(LibSDL::GLattr::SDL_GL_CONTEXT_MINOR_VERSION, 3)

    # Maybe for Dear ImGui
    LibSDL.gl_set_attribute(LibSDL::GLattr::SDL_GL_DOUBLEBUFFER, 1)
    LibSDL.gl_set_attribute(LibSDL::GLattr::SDL_GL_DEPTH_SIZE, 24)
    LibSDL.gl_set_attribute(LibSDL::GLattr::SDL_GL_STENCIL_SIZE, 8)

    {% unless flag?(:darwin) %}
      # todo: proper debug messages for mac
      LibGL.enable(LibGL::DEBUG_OUTPUT)
      LibGL.enable(LibGL::DEBUG_OUTPUT_SYNCHRONOUS)
      LibGL.debug_message_callback(->SDLOpenGLImGuiFrontend.callback, nil)
    {% end %}

    gl_context = LibSDL.gl_create_context @window
    LibSDL.gl_set_swap_interval(0) # disable vsync

    LibGL.blend_func(LibGL::SRC_ALPHA, LibGL::ONE_MINUS_SRC_ALPHA)

    frame_buffer = 0_u32
    LibGL.gen_textures(1, pointerof(frame_buffer))
    LibGL.active_texture(LibGL::TEXTURE0)
    LibGL.bind_texture(LibGL::TEXTURE_2D, frame_buffer)
    a = [LibGL::BLUE, LibGL::GREEN, LibGL::RED, LibGL::ONE] # flip the rgba to bgra where a is always 1
    a_ptr = pointerof(a).as(Int32*)
    LibGL.tex_parameter_iv(LibGL::TEXTURE_2D, LibGL::TEXTURE_SWIZZLE_RGBA, a_ptr)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MIN_FILTER, LibGL::NEAREST)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MAG_FILTER, LibGL::NEAREST)
    vao = 0_u32 # required even if not used in modern opengl
    LibGL.gen_vertex_arrays(1, pointerof(vao))
    LibGL.bind_vertex_array(vao)

    gl_context
  end

  private def create_shader_program(shader_name : String?) : UInt32
    return 0_u32 unless shader_name
    shader_program = LibGL.create_program
    vert_shader_id = compile_shader(File.read("#{SHADERS}/identity.vert"), LibGL::VERTEX_SHADER)
    frag_shader_id = compile_shader(File.read("#{SHADERS}/#{shader_name}"), LibGL::FRAGMENT_SHADER)
    LibGL.attach_shader(shader_program, vert_shader_id)
    LibGL.attach_shader(shader_program, frag_shader_id)
    LibGL.link_program(shader_program)
    LibGL.validate_program(shader_program)
    LibGL.use_program(shader_program)
    shader_program
  end

  private def setup_imgui : ImGui::ImGuiIO
    LibImGuiBackends.gl3wInit

    ImGui.debug_check_version_and_data_layout(
      ImGui.get_version, *{
      sizeof(LibImGui::ImGuiIO), sizeof(LibImGui::ImGuiStyle), sizeof(ImGui::ImVec2),
      sizeof(ImGui::ImVec4), sizeof(ImGui::ImDrawVert), sizeof(ImGui::ImDrawIdx),
    }.map &->LibC::SizeT.new(Int32))

    ImGui.create_context
    io = ImGui.get_io
    ImGui.style_colors_dark

    glsl_version = "#version 330"
    ImGui::SDL2.init_for_opengl(@window, @gl_context)
    ImGui::OpenGL3.init(glsl_version)

    io
  end

  protected def self.callback(source : UInt32, type : UInt32, id : UInt32, severity : UInt32, length : Int32, message : Pointer(UInt8), userParam : Pointer(Void)) : Nil
    puts "OpenGL debug message: #{String.new message}"
  end

  record OpenGLInfo, version : String, shading : String do
    def initialize
      @version = String.new(LibGL.get_string(LibGL::VERSION))
      @shading = String.new(LibGL.get_string(LibGL::SHADING_LANGUAGE_VERSION))
    end
  end
end
