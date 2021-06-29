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

  def render_menu : Nil
    if ImGui.begin_menu "Game Boy Advance"
      @emu.toggle_sync if ImGui.menu_item("Audio Sync", "", emu.apu.sync)
      ImGui.menu_item("Debug", "", pointerof(@debug_window))
      ImGui.end_menu
    end
  end

  def render_windows : Nil
    if @debug_window
      ImGui.begin("Debug", pointerof(@debug_window))
      ImGui.text("Palettes")
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
      ImGui.end
    end
  end
end
