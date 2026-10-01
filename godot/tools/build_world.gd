# Builds res://world.tscn from the imported terrain.
# Run: godot --headless --path . --script res://tools/build_world.gd
extends SceneTree

const TERRAIN_GLB := "res://assets/terrain.glb"
const COLLISION_RES := "res://assets/terrain_collision.res"
const WORLD_TSCN := "res://world.tscn"
const PLAYER_TSCN := "res://player.tscn"


func _init() -> void:
	var world := Node3D.new()
	world.name = "World"

	# Visual terrain: instance of the imported glTF scene.
	var terrain: Node3D = (load(TERRAIN_GLB) as PackedScene).instantiate()
	terrain.name = "Terrain"
	world.add_child(terrain)
	terrain.owner = world

	var mesh_instance := _find_mesh_instance(terrain)
	if mesh_instance == null:
		push_error("No MeshInstance3D in %s" % TERRAIN_GLB)
		quit(1)
		return

	# Collision: a trimesh built from the same triangles as the visual mesh.
	var shape := mesh_instance.mesh.create_trimesh_shape()
	var err := ResourceSaver.save(shape, COLLISION_RES)
	if err != OK:
		push_error("Saving %s failed: %s" % [COLLISION_RES, error_string(err)])
		quit(1)
		return

	var body := StaticBody3D.new()
	body.name = "TerrainBody"
	world.add_child(body)
	body.owner = world

	var collision := CollisionShape3D.new()
	collision.name = "TerrainCollision"
	collision.shape = load(COLLISION_RES)
	collision.transform = terrain.transform * mesh_instance.transform
	body.add_child(collision)
	collision.owner = world

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	world.add_child(sun)
	sun.owner = world

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.32, 0.52, 0.85)
	sky_material.sky_horizon_color = Color(0.70, 0.80, 0.90)
	sky_material.ground_horizon_color = Color(0.70, 0.80, 0.90)
	sky_material.ground_bottom_color = Color(0.25, 0.28, 0.25)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	world.add_child(world_env)
	world_env.owner = world

	# Invisible walls at the map edge (physics layer 3) so the player can't fall off.
	# The camera's spring arm only checks layer 1, so it ignores them.
	var bounds := StaticBody3D.new()
	bounds.name = "MapBounds"
	bounds.collision_layer = 1 << 2
	bounds.collision_mask = 0
	world.add_child(bounds)
	bounds.owner = world
	for side in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var wall := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.0, 10.0, 42.0) if side.x != 0 else Vector3(42.0, 10.0, 1.0)
		wall.shape = box
		wall.position = side * 20.0 + Vector3(0, 5.0, 0) + side * 0.5
		wall.name = "Wall%s" % ["East", "West", "South", "North"][[Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)].find(side)]
		bounds.add_child(wall)
		wall.owner = world

	# Player: spawns in the flat clearing at the center of the map.
	var player: Node3D = (load(PLAYER_TSCN) as PackedScene).instantiate()
	player.name = "Player"
	player.position = Vector3(0.0, 0.1, 0.0)
	world.add_child(player)
	player.owner = world

	var packed := PackedScene.new()
	err = packed.pack(world)
	if err == OK:
		err = ResourceSaver.save(packed, WORLD_TSCN)
	if err != OK:
		push_error("Saving %s failed: %s" % [WORLD_TSCN, error_string(err)])
		quit(1)
		return
	print("Saved %s (collision faces: %d)" % [WORLD_TSCN, shape.get_faces().size() / 3])
	world.free()
	quit(0)


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found:
			return found
	return null
