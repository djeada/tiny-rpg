# Adds the movement input actions (WASD + arrow keys) to project.godot if they are missing.
# Run: godot --headless --path . --script res://tools/setup_input.gd
extends SceneTree

const ACTIONS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
}


func _init() -> void:
	for action in ACTIONS:
		var setting: String = "input/" + action
		if ProjectSettings.has_setting(setting):
			print("exists: ", action)
			continue
		var events := []
		for key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.device = -1              # -1 = any keyboard
			ev.physical_keycode = key   # physical = same key position on any keyboard layout
			events.append(ev)
		ProjectSettings.set_setting(setting, {"deadzone": 0.2, "events": events})
		print("added: ", action)
	var err := ProjectSettings.save()
	print("project.godot saved: ", error_string(err))
	quit(0)
