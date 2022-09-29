module ImGui
  class Keybindings
    POPUP_NAME  = "Keybindings"
    BUTTON_SIZE = ImGui::ImVec2.new(32, 0)

    @config : Config
    @open = false
    @selection : Input? = nil
    @editing_keycodes : Hash(LibSDL::Keycode, Input) = {} of LibSDL::Keycode => Input

    delegate :[]?, to: @config.keybindings

    def initialize(@config : Config)
      overwrite_hash(@editing_keycodes, @config.keybindings)
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
        overwrite_hash(@editing_keycodes, @config.keybindings)
        ImGui.open_popup(POPUP_NAME)
      end
      center = ImGui.get_main_viewport.get_center
      ImGui.set_next_window_pos(center, ImGui::ImGuiCond::Appearing, ImGui::ImVec2.new(0.5, 0.5))
      hovered_button_color = ImGui.get_style_color_vec4(ImGui::ImGuiCol::ButtonHovered)
      ImGui.popup_modal(POPUP_NAME, flags: ImGui::ImGuiWindowFlags::AlwaysAutoResize) do
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
      end
    end

    private def overwrite_hash(to_hash : Hash(K, V), from_hash : Hash(K, V)) : Hash(K, V) forall K, V
      to_hash.clear
      from_hash.each { |key, val| to_hash[key] = val }
      to_hash
    end

    private def apply : Nil
      overwrite_hash(@config.keybindings, @editing_keycodes)
      @config.commit
      close
    end

    private def close : Nil
      @open = false
      @selection = nil
      ImGui.close_current_popup
    end
  end
end
