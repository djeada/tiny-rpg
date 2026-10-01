# Walks the player from the clearing up into the hills and reports the height reached.
# Run: godot --headless --path . --script res://tools/test_hills.gd
extends SceneTree


func _init() -> void:
	var world: Node3D = (load("res://world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_run.call_deferred(world.get_node("Player") as CharacterBody3D)


func _run(p: CharacterBody3D) -> void:
	for dir in ["move_forward", "move_left", "move_back", "move_right"]:
		p.position = Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		for i in 30:
			await physics_frame
		Input.action_press(dir)
		var top := 0.0
		var airborne := 0
		for i in 720:   # 12 s: long enough to reach the map edge
			await physics_frame
			top = maxf(top, p.position.y)
			if not p.is_on_floor():
				airborne += 1
		Input.action_release(dir)
		print("%-12s end=(%.1f, %.2f, %.1f) highest y=%.2f frames off floor=%d/720" % [dir, p.position.x, p.position.y, p.position.z, top, airborne])
	quit(0)
