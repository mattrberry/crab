require "./resolvable"

class Keybindings < Resolvable
  BUTTON_SIZE = ImGui::ImVec2.new(32, 0)

  @config : Config
  @selection : Input? = nil
  @editing_keycodes : Hash(LibSDL::Keycode, Input) = {} of LibSDL::Keycode => Input

  def initialize(@config : Config)
    @hovered_button_color = ImGui.get_style_color_vec4(ImGui::ImGuiCol::ButtonHovered)
  end

  delegate :[]?, to: @config.keybindings

  def wants_input? : Bool
    @visible && !@selection.nil?
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

  def render : Nil
    Input.each do |input|
      selected = @selection == input
      keycode = @editing_keycodes.key_for?(input)
      button_text = keycode ? String.new(LibSDL.get_key_name(keycode)) : ""
      ImGui.push_style_color(ImGui::ImGuiCol::Button, @hovered_button_color) if selected
      if ImGui.button(button_text, BUTTON_SIZE)
        @selection = input
      end
      ImGui.pop_style_color if selected
      ImGui.same_line
      ImGui.text(input.to_s)
    end
  end

  def reset : Nil
    @selection = nil
    overwrite_hash(@editing_keycodes, @config.keybindings)
  end

  def apply : Nil
    overwrite_hash(@config.keybindings, @editing_keycodes)
    @selection = nil
  end

  private def overwrite_hash(to_hash : Hash(K, V), from_hash : Hash(K, V)) : Hash(K, V) forall K, V
    to_hash.clear
    from_hash.each { |key, val| to_hash[key] = val }
    to_hash
  end
end
