class GBAController < Controller
  getter emu : GBA::GBA
  class_getter extensions : Array(String) = ["gba"]
  class_getter vertex_shader : String = "identity.vert"
  class_getter fragment_shader : String = "gba_colors.frag"

  getter width : Int32 = 240
  getter height : Int32 = 160

  @debug_window = false
  @scheduler_window = false

  def initialize(config : Config, bios : String?, rom : String)
    @emu = GBA::GBA.new(bios || config.gba.bios, rom, config.run_bios)
    @emu.post_init
  end

  # Audio

  def sync? : Bool
    @emu.apu.sync
  end

  # Debug

  def render_debug_items : Nil
    ImGui.menu_item("Video", "", pointerof(@debug_window))
    ImGui.menu_item("Scheduler", "", pointerof(@scheduler_window))
  end

  def render_windows : Nil
    if @debug_window
      ImGui.window("Video", pointerof(@debug_window)) do
        ImGui.tab_bar "VideoTabBar" do
          render_palettes_tab_item
        end
      end
    end
    if @scheduler_window
      cycles = @emu.scheduler.cycles
      ImGui.window("Scheduler", pointerof(@scheduler_window)) do
        ImGui.text("Total cycles: #{cycles}")
        ImGui.table("Table", 2) do
          ImGui.table_setup_column("Cycles")
          ImGui.table_setup_column("Type")
          ImGui.table_headers_row
          @emu.scheduler.events.each do |event|
            ImGui.table_next_row
            ImGui.table_set_column_index 0
            ImGui.text_unformatted (event.cycles - cycles).to_s
            ImGui.table_set_column_index 1
            ImGui.text_unformatted event.type.to_s
          end
        end
      end
    end
  end

  private def render_palettes_tab_item : Nil
    ImGui.tab_item("Palettes") do
      pram = @emu.ppu.pram.to_unsafe.as(UInt16*)
      flags = ImGui::ImGuiColorEditFlags::NoAlpha | ImGui::ImGuiColorEditFlags::NoPicker |
              ImGui::ImGuiColorEditFlags::NoOptions | ImGui::ImGuiColorEditFlags::NoInputs |
              ImGui::ImGuiColorEditFlags::NoLabel | ImGui::ImGuiColorEditFlags::NoSidePreview |
              ImGui::ImGuiColorEditFlags::NoDragDrop | ImGui::ImGuiColorEditFlags::NoBorder
      ImGui.with_style_var(ImGui::ImGuiStyleVar::ItemSpacing, ImGui::ImVec2.new(0, 0)) do
        2.times do |idx|
          ImGui.group do
            16.times do |palette_row|
              16.times do |palette_col|
                color = (pram + 0x100 * idx)[palette_row * 16 + palette_col]
                rgb = ImGui::ImVec4.new((color & 0x1F) / 0x1F, (color >> 5 & 0x1F) / 0x1F, (color >> 10 & 0x1F) / 0x1F, 1)
                ImGui.color_button("", rgb, flags, ImGui::ImVec2.new(10, 10))
                ImGui.same_line unless palette_col == 15
              end
            end
          end
          ImGui.same_line(spacing: 4_f32) if idx == 0
        end
      end
    end
  end
end
