class ConfigEditor
  getter keybindings : Keybindings
  property open : Bool = false
  @previously_open : Bool = false

  def initialize(@config : Config, @file_explorer : ImGui::FileExplorer)
    @bios_selection = BiosSelection.new(@config, @file_explorer)
    @keybindings = Keybindings.new @config
  end

  def render : Nil
    reset if @open && !@previously_open
    @previously_open = @open

    if @open
      ImGui.begin("Settings", pointerof(@open), flags: ImGui::ImGuiWindowFlags::AlwaysAutoResize)
      apply if ImGui.button("Apply")
      ImGui.same_line
      reset if ImGui.button("Revert")
      ImGui.same_line
      if ImGui.button("OK")
        apply
        @open = false
      end

      ImGui.separator

      ImGui.tab_bar("SettingsTabBar") do
        render_resolvable_tab(@bios_selection, "BIOS")
        render_resolvable_tab(@keybindings, "Keybindings")
      end
      ImGui.end
    end
  end

  private def reset : Nil
    @bios_selection.reset
    @keybindings.reset
  end

  private def apply : Nil
    @bios_selection.apply
    @keybindings.apply
    @config.commit
  end

  # Render a Resolvable in a tab item and set its `vislble` property.
  private def render_resolvable_tab(res : Resolvable, name : String) : Nil
    if res.visible = ImGui.begin_tab_item(name)
      ImGui.group do
        res.render
      end
      ImGui.end_tab_item
    end
  end
end
