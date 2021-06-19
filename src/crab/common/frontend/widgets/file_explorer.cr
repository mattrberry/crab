module ImGui
  class FileExplorer
    property extensions = [] of String
    @matched_entries = [] of Entry
    @selected_entry_idx = 0

    @path : Path
    @name = "File Explorer"

    getter chosen_rom : Path? = nil

    def initialize(@extensions = [] of String, @path = Path["~/Downloads/gba"].expand(home: true))
      gather_entries
    end

    def render(open_popup : Bool) : Nil
      ImGui.open_popup(@name) if open_popup
      center = ImGui.get_main_viewport.get_center
      ImGui.set_next_window_pos(center, ImGui::ImGuiCond::Appearing, ImGui::ImVec2.new(0.5, 0.5))
      if ImGui.begin_popup_modal(@name, flags: ImGui::ImGuiWindowFlags::AlwaysAutoResize)
        ImGui.text("This is some text")
        if ImGui.begin_list_box("Files")
          @matched_entries.each_with_index do |entry, idx|
            is_selected = idx == @selected_entry_idx
            if entry[:file?]
              letter = 'F'
              flags = ImGui::ImGuiSelectableFlags::None
            else
              letter = 'D'
              flags = ImGui::ImGuiSelectableFlags::None | ImGui::ImGuiSelectableFlags::AllowDoubleClick
            end
            if ImGui.selectable("[#{letter}] #{entry[:name]}", is_selected, flags)
              if entry[:file?]
                @selected_entry_idx = idx
              elsif ImGui.is_mouse_double_clicked(ImGui::ImGuiMouseButton::Left)
                change_dir entry[:name]
              end
            end
            ImGui.set_item_default_focus if is_selected
          end
          ImGui.end_list_box
        end
        open_file if ImGui.button "Open"
        ImGui.same_line
        ImGui.close_current_popup if ImGui.button "Cancel"
        ImGui.end_popup
      end
    end

    def clear_chosen_rom : Nil
      @chosen_rom = nil
    end

    private def open_file : Nil
      selected_item = @matched_entries[@selected_entry_idx]
      puts "Opening file #{selected_item[:name]}"
      @chosen_rom = (@path / selected_item[:name]).normalize
      ImGui.close_current_popup
    end

    private def change_dir(name : String) : Nil
      puts "Changing directory #{name}"
      @path = (@path / name).normalize
      gather_entries
    end

    private def gather_entries : Nil
      @matched_entries.clear
      extensions.each do |extension|
        path = @path / "*.#{extension}"
        @matched_entries.concat(Dir[path].map { |file| Entry.new(name: Path[file].basename, file?: true) })
      end
      Dir.each_child(@path) do |child|
        @matched_entries << Entry.new(name: "#{child}/", file?: false) if Dir.exists?(@path / child)
      end
      @matched_entries << Entry.new(name: "..", file?: false)
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

    private alias Entry = NamedTuple(name: String, file?: Bool)
  end
end
