require "imgui"
require "imgui-backends"
require "imgui-backends/lib"
require "lib_gl"

require "./controllers/*"
require "./widgets/*"
require "./shaders/*"

class SDLOpenGLImGuiFrontend < Frontend
  CONTROLLERS    = [StubbedController, GBController, GBAController]
  ROM_EXTENSIONS = CONTROLLERS.reduce([] of String) { |acc, controller| acc + controller.extensions }
  SHADERS        = Path["#{__DIR__}/shaders"]

  @config : Config
  @controller : Controller

  @window : SDL::Window
  @gl_context : LibSDL::GLContext
  @io : ImGui::ImGuiIO
  @shader_program : UInt32?
  @frag_shader_id : UInt32?

  @shader_programs : Hash(Controller.class, Shader)

  @microseconds = 0
  @frames = 0
  @last_time = Time.utc
  @seconds : Int32 = Time.utc.second

  @last_mouse_motion = 0_u32
  @enable_overlay = false
  @pause = false
  @scale = 3
  @fullscreen = false

  @opengl_info : OpenGLInfo

  @game_texture : UInt32 = 0
  @crab_texture : UInt32 = 0

  def initialize(@config : Config, bios : String?, rom : String?)
    SDL.init(SDL::Init::VIDEO | SDL::Init::AUDIO | SDL::Init::JOYSTICK)
    LibSDL.joystick_open 0
    at_exit { SDL.quit }

    @controller = init_controller(bios, rom, @config.run_bios)
    @window = SDL::Window.new(
      window_title(59.7),
      @controller.window_width * @scale,
      @controller.window_height * @scale,
      x: LibSDL::WindowPosition::CENTERED,
      y: LibSDL::WindowPosition::CENTERED,
      flags: SDL::Window::Flags::OPENGL | SDL::Window::Flags::RESIZABLE
    )
    @gl_context = setup_gl

    @shader_programs = Hash.zip(CONTROLLERS, CONTROLLERS.map { |controller| Shader.new(SHADERS / controller.vertex_shader, SHADERS / controller.fragment_shader) })
    shader_program = @shader_programs[@controller.class]
    shader_program.use

    if stubbed?
      @crab_texture, canvas_aspect = texture_from_png("README/crab.png")
      window_aspect = @window.width / @window.height
      shader_program.aspect = window_aspect * canvas_aspect
      shader_program.scale = 0.5
    end

    @opengl_info = OpenGLInfo.new
    @io = setup_imgui
    pause(true) if stubbed?

    @file_explorer = ImGui::FileExplorer.new @config
    @config_editor = ConfigEditor.new @config, @file_explorer
  end

  def run : NoReturn
    set_clear_color(60, 61, 107)
    loop do
      @controller.run_until_frame unless @pause
      handle_input
      LibGL.clear(LibGL::COLOR_BUFFER_BIT)
      if stubbed?
        render_logo
      else
        render_game
      end
      render_imgui
      LibSDL.gl_swap_window(@window)
      update_draw_count
    end
  end

  private def set_clear_color(red : Int, green : Int, blue : Int, alpha : Int = 255) : Nil
    LibGL.clear_color(red / 255, green / 255, blue / 255, alpha / 255)
  end

  def pause(b : Bool) : Nil
    if @pause != b
      @pause = b
      LibSDL.gl_set_swap_interval(@pause.to_unsafe)
    end
  end

  private def load_new_rom(rom : String?) : Nil
    LibSDL.close_audio(1)
    @controller = init_controller(nil, rom, @config.run_bios)

    @config.recents.delete(rom)
    @config.recents.insert(0, rom)
    @config.recents.pop(@config.recents.size - 8) if @config.recents.size > 8
    @config.commit

    LibSDL.set_window_size(@window, @controller.window_width * @scale, @controller.window_height * @scale)
    LibSDL.set_window_position(@window, LibSDL::WindowPosition::CENTERED, LibSDL::WindowPosition::CENTERED)
    @shader_programs[@controller.class].use
    LibGL.disable(LibGL::BLEND)

    pause(false)
  end

  private def handle_input : Nil
    while event = SDL::Event.poll
      ImGui::SDL2.process_event(event)
      case event
      when SDL::Event::Keyboard
        next if @io.want_capture_keyboard # let ImGui handle keyboard input when focused
        if @config_editor.keybindings.wants_input?
          @config_editor.keybindings.key_released(event.sym) unless event.pressed? # pass on key release
        elsif event.mod.includes?(LibSDL::Keymod::LCTRL)
          case event.sym
          when LibSDL::Keycode::P then pause(!@pause) unless event.pressed?
          when LibSDL::Keycode::F then @window.fullscreen = (@fullscreen = !@fullscreen) unless event.pressed?
          when LibSDL::Keycode::Q then exit
          end
        elsif input = @config_editor.keybindings[event.sym]?
          @controller.handle_input(input, event.pressed?)
        elsif event.sym == LibSDL::Keycode::TAB
          @controller.toggle_sync if event.pressed?
        end
      when SDL::Event::JoyHat, SDL::Event::JoyButton then @controller.handle_controller_event(event)
      when SDL::Event::Window
        case LibSDL::WindowEventID.new(event.event.to_i!)
        when LibSDL::WindowEventID::SIZE_CHANGED then LibGL.viewport(0, 0, @window.width, @window.height)
        end
      when SDL::Event::MouseMotion then @last_mouse_motion = event.timestamp
      when SDL::Event::Quit        then exit
      else                              nil
      end
    end
  end

  private def render_game : Nil
    @shader_programs[@controller.class].aspect = 1
    @shader_programs[@controller.class].scale = 1

    LibGL.bind_texture(LibGL::TEXTURE_2D, @game_texture)
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

  def render_logo : Nil
    LibGL.bind_texture(LibGL::TEXTURE_2D, @crab_texture)
    LibGL.draw_arrays(LibGL::TRIANGLE_STRIP, 0, 4)
  end

  private def stubbed? : Bool
    @controller.class == StubbedController
  end

  # Determine whether to show the main menu bar and set the cursor accordingly.
  # todo: don't time out menu bar when menu item is open
  private def show_menu_bar? : Bool
    window_focused = LibSDL.get_mouse_focus == @window.to_unsafe
    mouse_timed_out = LibSDL.get_ticks - @last_mouse_motion > 3000 # 3 second timeout
    res = stubbed? || (window_focused && !mouse_timed_out)
    LibSDL.show_cursor(res)
    res
  end

  private def render_imgui : Nil
    ImGui::OpenGL3.new_frame
    ImGui::SDL2.new_frame(@window)
    ImGui.new_frame

    overlay_height = 10.0
    open_rom_selection = false

    if show_menu_bar?
      ImGui.main_menu_bar do
        ImGui.menu "File" do
          open_rom_selection = ImGui.menu_item "Open ROM"
          ImGui.menu "Recent", @config.recents.size > 0 do
            @config.recents.each do |recent|
              load_new_rom(recent) if ImGui.menu_item recent
            end
            ImGui.separator
            if ImGui.menu_item "Clear"
              @config.recents.clear
              @config.commit
            end
          end
          ImGui.separator
          @config_editor.open = true if ImGui.menu_item "Settings"
          ImGui.separator
          exit if ImGui.menu_item "Exit", "Ctrl+Q"
        end

        ImGui.menu "Emulation" do
          pause = @pause

          ImGui.menu_item "Pause", "Ctrl+P", pointerof(pause)
          @controller.toggle_sync if ImGui.menu_item "Audio Sync", "Tab", @controller.sync?, !stubbed?

          pause(pause)
        end

        ImGui.menu "Audio/Video" do
          ImGui.menu "Frame size" do
            (1..8).each do |scale|
              if ImGui.menu_item "#{scale}x", selected: scale == @scale
                @scale = scale
                LibSDL.set_window_size(@window, @controller.window_width * @scale, @controller.window_height * @scale)
              end
            end
            ImGui.separator
            @window.fullscreen = @fullscreen if ImGui.menu_item "Fullscreen", "Ctrl+F", pointerof(@fullscreen)
          end
        end

        ImGui.menu "Debug" do
          ImGui.menu_item "Overlay", "", pointerof(@enable_overlay)
          ImGui.separator
          @controller.render_debug_items
        end

        overlay_height += ImGui.get_window_size.y
      end
    end

    @file_explorer.render("ROM", open_rom_selection, ROM_EXTENSIONS) do |path|
      load_new_rom(path.to_s)
    end

    @config_editor.render

    if @enable_overlay
      ImGui.set_next_window_pos(ImGui::ImVec2.new 10, overlay_height)
      ImGui.set_next_window_bg_alpha(0.5)
      ImGui.window("Overlay", pointerof(@enable_overlay),
        ImGui::ImGuiWindowFlags::NoDecoration | ImGui::ImGuiWindowFlags::NoMove |
        ImGui::ImGuiWindowFlags::NoSavedSettings) do
        io_framerate = @io.framerate
        ImGui.text("FPS:        #{io_framerate.format(decimal_places: 1)}")
        ImGui.text("Frame time: #{(1000 / io_framerate).format(decimal_places: 3)}ms")
        ImGui.separator
        ImGui.text("OpenGL")
        ImGui.text("  Version: #{@opengl_info.version}")
        ImGui.text("  Shading: #{@opengl_info.shading}")
      end
    end

    @controller.render_windows

    ImGui.render
    ImGui::OpenGL3.render_draw_data(ImGui.get_draw_data)
  end

  private def window_title(fps : Float) : String
    if stubbed?
      "crab"
    elsif @pause
      "crab - PAUSED"
    else
      "crab - #{fps.round(1)} fps"
    end
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

    LibGL.enable(LibGL::BLEND) if stubbed?
    LibGL.blend_func(LibGL::SRC_ALPHA, LibGL::ONE_MINUS_SRC_ALPHA)

    LibGL.gen_textures(1, out game_texture)
    LibGL.active_texture(LibGL::TEXTURE0)
    LibGL.bind_texture(LibGL::TEXTURE_2D, game_texture)
    @game_texture = game_texture
    a = [LibGL::BLUE, LibGL::GREEN, LibGL::RED, LibGL::ONE] # flip the rgba to bgra where a is always 1
    a_ptr = pointerof(a).as(Int32*)
    LibGL.tex_parameter_iv(LibGL::TEXTURE_2D, LibGL::TEXTURE_SWIZZLE_RGBA, a_ptr)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MIN_FILTER, LibGL::NEAREST)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MAG_FILTER, LibGL::NEAREST)

    LibGL.gen_vertex_arrays(1, out vao) # required even if not used in modern opengl
    LibGL.bind_vertex_array(vao)

    gl_context
  end

  private def texture_from_png(file : String) : Tuple(UInt32, Float64)
    canvas = StumpyPNG.read(file)
    pixels = canvas.pixels.map &.to_rgba
    LibGL.gen_textures(1, out crab_texture)
    LibGL.bind_texture(LibGL::TEXTURE_2D, crab_texture)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MIN_FILTER, LibGL::NEAREST)
    LibGL.tex_parameter_i(LibGL::TEXTURE_2D, LibGL::TEXTURE_MAG_FILTER, LibGL::NEAREST)
    LibGL.tex_image_2d(LibGL::TEXTURE_2D, 0, LibGL::RGBA, canvas.width, canvas.height, 0, LibGL::RGBA, LibGL::UNSIGNED_BYTE, pixels)
    {crab_texture, canvas.height / canvas.width}
  end

  private def setup_imgui : ImGui::ImGuiIO
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
