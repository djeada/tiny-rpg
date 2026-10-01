# Player controller: walks the hero around with WASD / arrow keys.
# All game logic lives here, not in the imported hero.glb.
extends CharacterBody3D

## How fast the player walks, in meters per second.
@export var move_speed := 2.0
## How quickly the player reaches full speed and stops (m/s per second).
@export var acceleration := 20.0
## How quickly the model turns to face where it is walking. Higher = snappier.
@export var turn_speed := 10.0
## The ground speed the Walk animation was made for. Used to keep the feet from sliding.
@export var walk_anim_speed := 1.5

# Gravity strength from Project Settings > Physics > 3D (9.8 by default).
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var model: Node3D = $Model
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var anim: AnimationPlayer = $Model/AnimationPlayer


func _ready() -> void:
	# Both clips should repeat forever (also set in the hero.glb import settings).
	anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	anim.get_animation("Walk").loop_mode = Animation.LOOP_LINEAR
	anim.play("Idle")


func _physics_process(delta: float) -> void:
	# 1. Gravity: fall when not standing on something.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# 2. Read the keys as a 2D vector: x = left/right, y = forward/back.
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# 3. Turn that into a 3D direction relative to where the camera looks,
	#    ignoring the camera's up/down tilt so we only move along the ground.
	var cam_forward := -camera.global_basis.z
	cam_forward.y = 0.0
	cam_forward = cam_forward.normalized()
	var cam_right := camera.global_basis.x
	cam_right.y = 0.0
	cam_right = cam_right.normalized()
	var direction := cam_right * input.x - cam_forward * input.y

	# 4. Speed up toward the target velocity (or slow down to zero with no input).
	var target := direction * move_speed
	velocity.x = move_toward(velocity.x, target.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, acceleration * delta)

	# 5. Move and let Godot handle slopes and collisions.
	move_and_slide()

	# 6. Smoothly turn the model toward the direction we are moving.
	#    The hero model faces its own +Z, so the angle is atan2(x, z).
	if direction.length() > 0.1:
		var target_angle := atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, 1.0 - exp(-turn_speed * delta))

	# 7. Pick the animation: Walk while moving, Idle while standing still.
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if ground_speed > 0.1:
		if anim.current_animation != "Walk":
			anim.play("Walk", 0.2)   # 0.2 s blend from the previous clip
		anim.speed_scale = ground_speed / walk_anim_speed
	else:
		if anim.current_animation != "Idle":
			anim.play("Idle", 0.2)
		anim.speed_scale = 1.0
