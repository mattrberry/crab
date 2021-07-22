class GBAController < Controller
  getter emu : GBA::GBA
  class_getter extensions : Array(String) = ["gba"]
  class_getter shader : String? = "gba_colors.frag"

  getter width : Int32 = 240
  getter height : Int32 = 160

  @debug_window = false

  def initialize(bios : String?, rom : String)
    @emu = GBA::GBA.new(bios || gba_bios, rom)
    @emu.post_init
  end

  # Audio

  def sync? : Bool
    @emu.apu.sync
  end

  # Debug

  def render_debug_items : Nil
    ImGui.menu_item("Video", "", pointerof(@debug_window))
  end

  def render_windows : Nil
    if @debug_window
      ImGui.begin("Video", pointerof(@debug_window))
      if ImGui.begin_tab_bar "VideoTabBar"
        render_palettes_tab_item if ImGui.begin_tab_item "Palettes"
        ImGui.end_tab_bar
      end
      ImGui.end
    end
  end

  private def render_palettes_tab_item : Nil
    ImGui.push_style_var(ImGui::ImGuiStyleVar::ItemSpacing, ImGui::ImVec2.new(0, 0))
    pram = @emu.ppu.pram.to_unsafe.as(UInt16*)
    flags = ImGui::ImGuiColorEditFlags::NoAlpha | ImGui::ImGuiColorEditFlags::NoPicker |
            ImGui::ImGuiColorEditFlags::NoOptions | ImGui::ImGuiColorEditFlags::NoInputs |
            ImGui::ImGuiColorEditFlags::NoLabel | ImGui::ImGuiColorEditFlags::NoSidePreview |
            ImGui::ImGuiColorEditFlags::NoDragDrop | ImGui::ImGuiColorEditFlags::NoBorder
    2.times do |idx|
      ImGui.begin_group
      16.times do |palette_row|
        16.times do |palette_col|
          color = (pram + 0x100 * idx)[palette_row * 16 + palette_col]
          rgb = ImGui::ImVec4.new((color & 0x1F) / 0x1F, (color >> 5 & 0x1F) / 0x1F, (color >> 10 & 0x1F) / 0x1F, 1)
          ImGui.color_button("", rgb, flags, ImGui::ImVec2.new(10, 10))
          ImGui.same_line unless palette_col == 15
        end
      end
      ImGui.end_group
      ImGui.same_line(spacing: 4_f32) if idx == 0
    end
    ImGui.pop_style_var
    ImGui.end_tab_item
  end
end
