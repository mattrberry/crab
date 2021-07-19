module ImGui
  class Keybindings
    POPUP_NAME  = "Keybindings"
    BUTTON_SIZE = ImGui::ImVec2.new(32, 0)

    @open = false
    @selection : Input? = nil
    @keycodes : Hash(LibSDL::Keycode, Input) = {
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
    @editing_keycodes : Hash(LibSDL::Keycode, Input) = {} of LibSDL::Keycode => Input

    delegate :[]?, to: @keycodes

    def initialize
      overwrite_hash(@editing_keycodes, @keycodes)
    end

    def open? : Bool
      @open
    end

    def wants_input? : Bool
      @open && !@selection.nil?
    end

    def key_released(keycode : LibSDL::Keycode) : Nil
      if selection = @selection
        @editing_keycodes.reject!(@editing_keycodes.key_for?(selection))
        @editing_keycodes[keycode] = selection
        @selection = Input.from_value?(selection.value + 1)
      else
        puts "Something went wrong when setting keybinding.."
      end
    end

    def render(open_popup : Bool) : Nil
      @open ||= open_popup
      if open_popup
        overwrite_hash(@editing_keycodes, @keycodes)
        ImGui.open_popup(POPUP_NAME)
      end
      center = ImGui.get_main_viewport.get_center
      ImGui.set_next_window_pos(center, ImGui::ImGuiCond::Appearing, ImGui::ImVec2.new(0.5, 0.5))
      hovered_button_color = ImGui.get_style_color_vec4(ImGui::ImGuiCol::ButtonHovered)
      if ImGui.begin_popup_modal(POPUP_NAME, flags: ImGui::ImGuiWindowFlags::AlwaysAutoResize)
        Input.each do |input|
          selected = @selection == input
          keycode = @editing_keycodes.key_for?(input)
          button_text = keycode ? String.new(LibSDL.get_key_name(keycode)) : ""
          x_pos = ImGui.get_window_content_region_max.x - BUTTON_SIZE.x
          ImGui.text(input.to_s)
          ImGui.same_line(x_pos)
          ImGui.push_style_color(ImGui::ImGuiCol::Button, hovered_button_color) if selected
          if ImGui.button(button_text, BUTTON_SIZE)
            @selection = input
          end
          ImGui.pop_style_color if selected
        end
        apply if ImGui.button "Apply"
        ImGui.same_line
        close if ImGui.button "Cancel"
        ImGui.end_popup
      end
    end

    private def apply : Nil
      overwrite_hash(@keycodes, @editing_keycodes)
      close
    end

    private def overwrite_hash(to_hash : Hash(K, V), from_hash : Hash(K, V)) : Hash(K, V) forall K, V
      to_hash.clear
      from_hash.each { |key, val| to_hash[key] = val }
      to_hash
    end

    private def close : Nil
      @open = false
      @selection = nil
      ImGui.close_current_popup
    end
  end
end
