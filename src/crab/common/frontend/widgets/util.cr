# Display a little (?) mark which shows a tooltip when hovered. Translated from
# the demo code.
def help_marker(desc : String) : Nil
  ImGui.text_disabled("(?)")
  if ImGui.is_item_hovered
    ImGui.tooltip do
      ImGui.with_text_wrap_pos(ImGui.get_font_size * 35_f32) do
        ImGui.text_unformatted(desc)
      end
    end
  end
end
