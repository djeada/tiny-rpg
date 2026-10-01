# Drives the player with simulated input and checks movement, facing and animation.
# Run: godot --headless --path . --script res://tools/test_player_input.gd
extends SceneTree

var _p: CharacterBody3D


func _init() -> void:
	var world: Node3D = (load("res://world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_p = (load("res://player.tscn") as PackedScene).instantiate()
	_p.position = Vector3(0, 0.3, 0)
	world.add_child(_p)
	_run.call_deferred()


func _step(frames: int) -> void:
	for i in frames:
		await physics_frame


func _report(label: String) -> void:
	var anim := _p.get_node("Model/AnimationPlayer") as AnimationPlayer
	# Visual front of the model = its +Z axis (see player.gd).
	var front: Vector3 = (_p.get_node("Model") as Node3D).global_basis.z
	print("%-22s pos=(%.2f, %.3f, %.2f) vel=(%.2f, %.2f, %.2f) front=(%.2f, %.2f) floor=%s anim=%s x%.2f" % [
		label, _p.position.x, _p.position.y, _p.position.z, _p.velocity.x, _p.velocity.y, _p.velocity.z,
		front.x, front.z, _p.is_on_floor(), anim.current_animation, anim.speed_scale])


func _run() -> void:
	var anim := _p.get_node("Model/AnimationPlayer") as AnimationPlayer
	print("script=%s speed=%.1f accel=%.1f turn=%.1f gravity=%.1f" % [_p.get_script().resource_path, _p.move_speed, _p.acceleration, _p.turn_speed, _p.gravity])
	print("loop modes: Idle=%d Walk=%d" % [anim.get_animation("Idle").loop_mode, anim.get_animation("Walk").loop_mode])
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		print("  %s: %s" % [a, InputMap.action_get_events(a).map(func(e): return e.as_text())])
	await _step(60)
	_report("idle on ground")
	var start := _p.position

	Input.action_press("move_forward")
	await _step(90)
	_report("W held 1.5 s")
	Input.action_release("move_forward")

	Input.action_press("move_right")
	await _step(60)
	_report("D held 1 s")
	Input.action_release("move_right")

	await _step(30)
	_report("released 0.5 s")

	# Arrow keys go through the same actions.
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_DOWN
	ev.pressed = true
	Input.parse_input_event(ev)
	await _step(60)
	_report("Down arrow held 1 s")
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)
	await _step(40)
	_report("released")
	print("net displacement: ", _p.position - start)
	quit(0)
