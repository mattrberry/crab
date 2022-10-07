require "./resolvable"

class BiosSelection < Resolvable
  RED_TEXT_COL = ImGui::ImVec4.new(1, 0.5, 0.5, 1)

  @config : Config
  @file_explorer : ImGui::FileExplorer

  @gbc_bios_text_buffer = ImGui::TextBuffer.new(128)
  @gba_bios_text_buffer = ImGui::TextBuffer.new(128)
  @gbc_bios_text_buffer_valid = false
  @gba_bios_text_buffer_valid = false
  @run_bios : Bool = false # initialized on reset

  def initialize(@config : Config, @file_explorer : ImGui::FileExplorer)
  end

  def render : Nil
    ImGui.text("GBC BIOS File:")
    ImGui.same_line
    gbc_bios_text_buffer_valid = @gbc_bios_text_buffer_valid
    ImGui.push_style_color(ImGui::ImGuiCol::Text, RED_TEXT_COL) unless gbc_bios_text_buffer_valid
    ImGui.input_text_with_hint("##gbc_bios", "optional", @gbc_bios_text_buffer, ImGui::ImGuiInputTextFlags::CallbackAlways) do
      @gbc_bios_text_buffer_valid = @gbc_bios_text_buffer.bytesize == 0 || File.file?(@gbc_bios_text_buffer.to_s)
      0 # allow input to proceed
    end
    ImGui.pop_style_color unless gbc_bios_text_buffer_valid
    ImGui.same_line
    gbc_bios_browse = ImGui.button("Browse##gbc_bios")

    ImGui.text("GBA BIOS File:")
    ImGui.same_line
    gba_bios_text_buffer_valid = @gba_bios_text_buffer_valid
    ImGui.push_style_color(ImGui::ImGuiCol::Text, RED_TEXT_COL) unless gba_bios_text_buffer_valid
    ImGui.input_text_with_hint("##gba_bios", "optional", @gba_bios_text_buffer, ImGui::ImGuiInputTextFlags::CallbackAlways) do |data|
      @gba_bios_text_buffer_valid = @gba_bios_text_buffer.bytesize == 0 || File.file?(@gba_bios_text_buffer.to_s)
      0 # allow input to proceed
    end
    ImGui.pop_style_color unless gba_bios_text_buffer_valid
    ImGui.same_line
    gba_bios_browse = ImGui.button("Browse##gba_bios")

    ImGui.indent(106) # align with text boxes above
    ImGui.checkbox("Run BIOS intro", pointerof(@run_bios))
    ImGui.unindent(106)

    @file_explorer.render("GBC BIOS", gbc_bios_browse) do |path|
      @gbc_bios_text_buffer.clear
      @gbc_bios_text_buffer.write(path.to_s.to_slice)
      @gbc_bios_text_buffer_valid = @gbc_bios_text_buffer.bytesize == 0 || File.file?(@gbc_bios_text_buffer.to_s)
    end
    @file_explorer.render("GBA BIOS", gba_bios_browse) do |path|
      @gba_bios_text_buffer.clear
      @gba_bios_text_buffer.write(path.to_s.to_slice)
      @gba_bios_text_buffer_valid = @gba_bios_text_buffer.bytesize == 0 || File.file?(@gba_bios_text_buffer.to_s)
    end
  end

  def reset : Nil
    @gbc_bios_text_buffer.clear
    @gba_bios_text_buffer.clear
    if gbc_bios = @config.gbc.bios
      @gbc_bios_text_buffer.write(gbc_bios.to_slice)
      @gbc_bios_text_buffer_valid = File.file?(@gbc_bios_text_buffer.to_s)
    end
    if gba_bios = @config.gba.bios
      @gba_bios_text_buffer.write(gba_bios.to_slice) if Path[gba_bios].normalize != Path[Config::GBA::DEFAULT_BIOS].normalize
      @gba_bios_text_buffer_valid = File.file?(@gba_bios_text_buffer.to_s)
    end
    @run_bios = @config.run_bios
  end

  def apply : Nil
    @config.gbc.bios = nil
    @config.gbc.bios = @gbc_bios_text_buffer.to_s if @gbc_bios_text_buffer.bytesize != 0
    @config.gba.bios = nil
    @config.gba.bios = @gba_bios_text_buffer.to_s if @gba_bios_text_buffer.bytesize != 0
    @config.run_bios = @run_bios
  end
end
