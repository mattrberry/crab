# Represents a widget which stores temporary state that can be committed or
# dropped on request.
abstract class Resolvable
  # Whether the widget is visible.
  property visible : Bool = false

  # Called once per frame for rendering the widget.
  abstract def render : Nil
  # Called to indicate the widget should be reset.
  abstract def reset : Nil
  # Called to indicate the selection should be written back to the config.
  abstract def apply : Nil
end
