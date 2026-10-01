# Checks player.tscn inside world.tscn: capsule fit, facing, active camera, spring-arm collision.
# Run: godot --headless --path . --script res://tools/verify_player.gd
extends SceneTree

var _world: Node3D
var _player: CharacterBody3D


func _init() -> void:
	_world = (load("res://world.tscn") as PackedScene).instantiate()
	root.add_child(_world)
	_player = (load("res://player.tscn") as PackedScene).instantiate()
	_player.position = Vector3(0.0, 0.5, 0.0)
	_world.add_child(_player)
	_print_tree(_player, 0)
	_run.call_deferred()


func _run() -> void:
	await physics_frame
	var model := _player.get_node("Model") as Node3D
	var mesh_node := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var mesh := mesh_node.mesh
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var to_player := _player.global_transform.affine_inverse() * mesh_node.global_transform

	# Bounds of the hero in player space, and the nose (only geometry near x=0 at face height).
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var nose_z := 0.0
	var nose_n := 0
	var glb_nose_z := 0.0
	for v in verts:
		var p := to_player * v
		lo = lo.min(p)
		hi = hi.max(p)
		if absf(v.x) < 0.025 and v.y > 1.59 and v.y < 1.65:
			nose_z += p.z
			glb_nose_z += v.z
			nose_n += 1
	print("\nhero bounds (player space): min=%s max=%s" % [lo, hi])
	print("nose: glTF z=%.3f -> player z=%.3f over %d verts (player forward is -Z)" % [glb_nose_z / nose_n, nose_z / nose_n, nose_n])

	var col := _player.get_node("CollisionShape3D") as CollisionShape3D
	var cap := col.shape as CapsuleShape3D
	print("capsule: radius=%.2f height=%.2f spans y %.2f..%.2f; hero half-width x=%.3f z=%.3f" % [
		cap.radius, cap.height, col.position.y - cap.height / 2, col.position.y + cap.height / 2,
		maxf(-lo.x, hi.x), maxf(-lo.z, hi.z)])

	# Let the body settle on the terrain with gravity.
	for i in 60:
		_player.velocity.y -= 9.8 / 60.0
		_player.move_and_slide()
		await physics_frame
	print("settled: y=%.4f on_floor=%s" % [_player.global_position.y, _player.is_on_floor()])

	var arm := _player.get_node("SpringArm3D") as SpringArm3D
	var cam := arm.get_node("Camera3D") as Camera3D
	await physics_frame
	print("active camera: %s (current=%s)" % [root.get_viewport().get_camera_3d().get_path(), cam.current])
	var cam_rel := cam.global_position - _player.global_position
	print("open arm: hit_length=%.2f / %.2f, camera offset from feet=%s" % [arm.get_hit_length(), arm.spring_length, cam_rel])

	# Drop a wall 2 m behind the player and let the arm react.
	var wall := StaticBody3D.new()
	var box := CollisionShape3D.new()
	box.shape = BoxShape3D.new()
	(box.shape as BoxShape3D).size = Vector3(6.0, 6.0, 0.5)
	wall.add_child(box)
	wall.position = _player.global_position + Vector3(0.0, 1.5, 2.0)
	_world.add_child(wall)
	await physics_frame
	await physics_frame
	await process_frame
	print("wall 2 m behind: hit_length=%.2f, camera offset from feet=%s" % [arm.get_hit_length(), cam.global_position - _player.global_position])
	wall.queue_free()
	await physics_frame
	await physics_frame
	await process_frame
	print("wall removed: hit_length=%.2f" % arm.get_hit_length())
	quit(0)


func _print_tree(node: Node, depth: int) -> void:
	var extra := ""
	if node is CharacterBody3D:
		extra = " layer=%d mask=%d" % [node.collision_layer, node.collision_mask]
	elif node is CollisionShape3D:
		extra = " %s pos=%s" % [node.shape.get_class(), node.position]
	elif node is SpringArm3D:
		extra = " pos=%s rot=%s length=%.2f mask=%d" % [node.position, node.rotation_degrees, node.spring_length, node.collision_mask]
	elif node is Camera3D:
		extra = " current=%s" % node.current
	elif node.name == "Model":
		extra = " rot=%s (instance of %s)" % [node.rotation_degrees, node.scene_file_path]
	print("  ".repeat(depth + 1), node.name, " (", node.get_class(), ")", extra)
	if node.name == "Model" and depth > 0:
		return
	for child in node.get_children():
		_print_tree(child, depth + 1)
