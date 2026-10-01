# Loads world.tscn and hero.glb, prints the scene tree, and raycasts the terrain collision.
# Run: godot --headless --path . --script res://tools/verify_world.gd
extends SceneTree

var _world: Node3D


func _init() -> void:
	print("main_scene = ", ProjectSettings.get_setting("application/run/main_scene"))
	_world = (load("res://world.tscn") as PackedScene).instantiate()
	root.add_child(_world)
	_print_tree(_world, 0)

	var hero: Node = (load("res://assets/hero.glb") as PackedScene).instantiate()
	print("\nhero.glb:")
	_print_tree(hero, 0)
	var player := hero.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player:
		for anim_name in player.get_animation_list():
			var anim := player.get_animation(anim_name)
			print("  anim %s: length=%.3fs loop_mode=%d tracks=%d" % [anim_name, anim.length, anim.loop_mode, anim.get_track_count()])
	hero.free()
	_raycast_check.call_deferred()


func _raycast_check() -> void:
	await physics_frame
	await physics_frame
	var space := _world.get_world_3d().direct_space_state
	var mesh := (_world.find_child("Terrain", true, false).find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var aabb := mesh.get_aabb()
	print("\nterrain mesh AABB: ", aabb)
	var max_err := 0.0
	var misses := 0
	var samples := 0
	var highest := -INF
	for ix in range(-19, 20, 2):
		for iz in range(-19, 20, 2):
			var q := PhysicsRayQueryParameters3D.create(Vector3(ix + 0.3, 20.0, iz + 0.7), Vector3(ix + 0.3, -5.0, iz + 0.7))
			var hit := space.intersect_ray(q)
			samples += 1
			if hit.is_empty():
				misses += 1
				continue
			highest = max(highest, hit.position.y)
	var center := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 20, 0), Vector3(0, -5, 0)))
	print("raycasts: %d samples, %d misses, highest hit y=%.3f, center hit y=%.4f collider=%s" % [samples, misses, highest, center.position.y, center.collider.name])
	quit(0)


func _print_tree(node: Node, depth: int) -> void:
	var extra := ""
	if node is MeshInstance3D and node.mesh:
		extra = " mesh=%s surfaces=%d" % [node.mesh.resource_name, node.mesh.get_surface_count()]
	elif node is CollisionShape3D and node.shape:
		extra = " shape=%s faces=%d" % [node.shape.get_class(), node.shape.get_faces().size() / 3]
	elif node is DirectionalLight3D:
		extra = " shadows=%s rot=%s" % [node.shadow_enabled, node.rotation_degrees]
	elif node is WorldEnvironment:
		extra = " bg=%d sky=%s" % [node.environment.background_mode, node.environment.sky.sky_material.get_class()]
	elif node is Skeleton3D:
		extra = " bones=%d" % node.get_bone_count()
	print("  ".repeat(depth + 1), node.name, " (", node.get_class(), ")", extra)
	for child in node.get_children():
		_print_tree(child, depth + 1)
