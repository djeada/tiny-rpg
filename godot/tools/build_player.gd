# Builds res://player.tscn around the imported hero.
# Run: godot --headless --path . --script res://tools/build_player.gd
extends SceneTree

const HERO_GLB := "res://assets/hero.glb"
const PLAYER_TSCN := "res://player.tscn"
const PLAYER_SCRIPT := "res://player.gd"

# Physics layers: 1 = world geometry, 2 = player, 3 = map bounds (blocks player only).
const LAYER_WORLD := 1
const LAYER_PLAYER := 2

const HERO_HEIGHT := 1.8
const CAPSULE_RADIUS := 0.33          # hero is 0.65 m wide at the arms, 0.30 m deep

const ARM_PIVOT := Vector3(0.0, 1.2, 0.0)   # chest height
const ARM_PITCH_DEG := -12.0
const ARM_LENGTH := 4.1                     # camera ends ~4.0 m behind and ~2.05 m above the feet


func _init() -> void:
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.set_script(load(PLAYER_SCRIPT))
	player.collision_layer = 1 << (LAYER_PLAYER - 1)
	player.collision_mask = (1 << (LAYER_WORLD - 1)) | (1 << 2)

	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = HERO_HEIGHT
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = capsule
	collision.position = Vector3(0.0, HERO_HEIGHT * 0.5, 0.0)
	_add(player, player, collision)

	# The hero is authored facing +Z (glTF front). Godot's forward is -Z, so turn it around.
	var model: Node3D = (load(HERO_GLB) as PackedScene).instantiate()
	model.name = "Model"
	model.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	_add(player, player, model)

	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.position = ARM_PIVOT
	arm.rotation_degrees = Vector3(ARM_PITCH_DEG, 0.0, 0.0)
	arm.spring_length = ARM_LENGTH
	arm.collision_mask = 1 << (LAYER_WORLD - 1)
	var probe := SphereShape3D.new()
	probe.radius = 0.2
	arm.shape = probe
	arm.margin = 0.05
	_add(player, player, arm)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.fov = 70.0
	camera.far = 200.0
	_add(player, arm, camera)

	var packed := PackedScene.new()
	var err := packed.pack(player)
	if err == OK:
		err = ResourceSaver.save(packed, PLAYER_TSCN)
	if err != OK:
		push_error("Saving %s failed: %s" % [PLAYER_TSCN, error_string(err)])
		quit(1)
		return
	print("Saved ", PLAYER_TSCN)
	player.free()
	quit(0)


func _add(owner_node: Node, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = owner_node
