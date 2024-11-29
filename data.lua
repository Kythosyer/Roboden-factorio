data:extend({
  { type = "custom-input", name = "roboden-toggle-gui", key_sequence = "CONTROL + I", action = "lua" },
  {
    type = "shortcut",
    name = "roboden-toggle-gui",
    icon = "__RoboDensity__/graphics/den.png",
    icon_size = 32,
    small_icon = "__RoboDensity__/graphics/den.png",
    small_icon_size = 24,
    toggleable = true,
    action = "lua",
    associated_control_input = "roboden-toggle-gui"
  },
})
local styles = data.raw["gui-style"]["default"]


styles.roboden_frame = {
  type = "frame_style",
  padding = 6,
  top_padding = 4,
  horizontally_stretchable = "on",
  vertically_stretchable = "on"
}
