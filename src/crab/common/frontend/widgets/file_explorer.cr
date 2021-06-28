module ImGui
  class FileExplorer
    @matched_entries = [] of Entry
    @selected_entry_idx = 0
    @match_hidden = false

    @path : Path
    @name = "File Explorer"

    getter selection : Path? = nil

    def initialize(@path = Path[explorer_dir].expand(home: true))
      gather_entries
    end

    def render(open_popup : Bool, extensions : Array(String)?) : Nil
      ImGui.open_popup(@name) if open_popup
      center = ImGui.get_main_viewport.get_center
      ImGui.set_next_window_pos(center, ImGui::ImGuiCond::Appearing, ImGui::ImVec2.new(0.5, 0.5))
      if ImGui.begin_popup_modal(@name, flags: ImGui::ImGuiWindowFlags::AlwaysAutoResize)
        parts = @path.parts
        parts.each_with_index do |part, idx|
          ImGui.same_line unless idx == 0
          change_dir "../" * (parts.size - idx - 1) if ImGui.button(part)
        end
        display_size = ImGui.get_main_viewport.size
        width = Math.min(display_size.x - 40, 600)
        height = Math.min(display_size.y - 40, 16 * ImGui.get_text_line_height_with_spacing)
        if ImGui.begin_list_box("", ImGui::ImVec2.new(width, height))
          @matched_entries.each_with_index do |entry, idx|
            next if entry[:hidden] && !@match_hidden
            next if entry[:file?] && !extensions.nil? && !extensions.includes?(entry[:extension])
            is_selected = idx == @selected_entry_idx
            if entry[:file?]
              letter = 'F'
              flags = ImGui::ImGuiSelectableFlags::AllowDoubleClick
            else
              letter = 'D'
              flags = ImGui::ImGuiSelectableFlags::None | ImGui::ImGuiSelectableFlags::AllowDoubleClick
            end
            if ImGui.selectable("[#{letter}] #{entry[:name]}#{'/' unless entry[:file?]}", is_selected, flags)
              if entry[:file?]
                @selected_entry_idx = idx
                open_file if ImGui.is_mouse_double_clicked(ImGui::ImGuiMouseButton::Left)
              elsif ImGui.is_mouse_double_clicked(ImGui::ImGuiMouseButton::Left)
                change_dir entry[:name]
              end
            end
            ImGui.set_item_default_focus if is_selected
          end
          ImGui.end_list_box
        end
        ImGui.begin_group
        open_file if ImGui.button "Open"
        ImGui.same_line
        ImGui.close_current_popup if ImGui.button "Cancel"
        ImGui.same_line(spacing: 10)
        ImGui.checkbox("Show hidden files?", pointerof(@match_hidden))
        ImGui.end_group
        ImGui.end_popup
      end
    end

    def clear_selection : Nil
      @selection = nil
    end

    private def open_file : Nil
      @selection = (@path / @matched_entries[@selected_entry_idx][:name]).normalize
      ImGui.close_current_popup
      set_explorer_dir @path.to_s
    end

    private def change_dir(name : String) : Nil
      @path = (@path / name).normalize
      gather_entries
    end

    private def gather_entries : Nil
      @matched_entries.clear
      Dir.each_child(@path) do |name|
        is_file = !Dir.exists?(@path / name)
        rpart = name.rpartition('.')
        extension = rpart[2] unless rpart[1].size == 0
        hidden = name.starts_with?('.')
        @matched_entries << Entry.new(name: name, file?: is_file, extension: extension, hidden: hidden)
      end
      @matched_entries << Entry.new(name: "..", file?: false, extension: nil, hidden: false)
      @matched_entries.sort! do |a, b|
        if a[:file?] && !b[:file?]
          1
        elsif !a[:file?] && b[:file?]
          -1
        else
          a[:name] <=> b[:name]
        end
      end
    end

    private alias Entry = NamedTuple(name: String, file?: Bool, extension: String?, hidden: Bool)
  end
end
