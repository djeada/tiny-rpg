# Scripted cinematic for the teaser. Loads the real world + player, drives the hero along a
# route through the player's own input actions, and cuts between camera shots.
# Render: godot --path . --resolution 1920x1080 --fixed-fps 30 \
#           --write-movie <dir>/frame.png res://tools/teaser/teaser.tscn
extends Node3D

const LENGTH := 30.0
const WALK_START := 10.0
const WALK_STOP := 27.5
const ROUTE: Array[Vector2] = [
	Vector2(0, -8), Vector2(6, -14), Vector2(13, -9), Vector2(4, -17),   # last leg heads into the sun
]

var t := 0.0
var world: Node3D
var player: CharacterBody3D
var cam: Camera3D
var cam_attr: CameraAttributesPractical
var _wp := 0
var _steer := Vector3(0, 0, -1)
var _side := Vector3.ZERO
var _heading := Vector3(0, 0, -1)
var _crane_from: Transform3D
var _shot := -1


func _ready() -> void:
	world = (load("res://world.tscn") as PackedScene).instantiate()
	add_child(world)
	player = world.get_node("Player")
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 300.0
	cam_attr = CameraAttributesPractical.new()
	cam.attributes = cam_attr
	add_child(cam)
	cam.make_current()
	_golden_hour()


func _golden_hour() -> void:
	var sun := world.get_node("Sun") as DirectionalLight3D
	sun.rotation_degrees = Vector3(-17.0, 215.0, 0.0)   # low sun, lighting the hero's front-left
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 1.6
	sun.shadow_blur = 1.5
	var env := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color(0.20, 0.34, 0.62)
	sky.sky_horizon_color = Color(0.96, 0.72, 0.52)
	sky.ground_horizon_color = Color(0.93, 0.74, 0.56)   # below the horizon = same haze as the fog,
	sky.ground_bottom_color = Color(0.62, 0.58, 0.42)    # so nothing past the map edge stands out
	sky.sun_angle_max = 20.0
	sky.sun_curve = 0.08
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ambient_light_energy = 0.7
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.fog_enabled = true
	env.fog_light_color = Color(0.93, 0.74, 0.56)
	env.fog_density = 0.012
	env.fog_aerial_perspective = 0.8
	env.fog_sky_affect = 0.2


func _physics_process(delta: float) -> void:
	_drive_hero()


func _process(delta: float) -> void:
	t += delta
	var hero := player.global_position
	var shot := _shot_at(t)
	if shot != _shot:
		_shot = shot
		_on_cut(shot)

	match shot:
		0: _aerial(hero, _u(0.0, 6.0))
		1: _orbit(hero, _u(6.0, 10.0))
		2: _lead(hero, _u(10.0, 14.0))
		3: _side_track(hero, delta)
		4: pass   # gameplay camera
		5: _crane(hero, _u(24.0, LENGTH))
	if shot != 4:
		_keep_above_ground()
	if t >= LENGTH + 0.05:
		get_tree().quit()


func _shot_at(time: float) -> int:
	for i in [[6.0, 0], [10.0, 1], [14.0, 2], [19.0, 3], [24.0, 4]]:
		if time < i[0]:
			return i[1]
	return 5


func _on_cut(shot: int) -> void:
	cam_attr.dof_blur_far_enabled = shot in [1, 2, 3]
	cam_attr.dof_blur_far_distance = 7.0
	cam_attr.dof_blur_far_transition = 12.0
	cam_attr.dof_blur_amount = 0.06
	if shot == 4:
		(player.get_node("SpringArm3D/Camera3D") as Camera3D).make_current()
	else:
		cam.make_current()
	if shot == 3:
		_side = Vector3.ZERO
	if shot == 5:
		_heading = Vector3(player.velocity.x, 0, player.velocity.z).normalized()
		_crane_from = (player.get_node("SpringArm3D/Camera3D") as Camera3D).global_transform


# --- shots -----------------------------------------------------------------------------------

func _aerial(hero: Vector3, u: float) -> void:
	var e := _ease(u)
	var p := _bezier(Vector3(-15, 7.5, 15), Vector3(-19, 5.0, -2), Vector3(-9, 2.4, -12), Vector3(-2.2, 1.5, -5.2), e)
	cam.fov = lerpf(55.0, 42.0, e)
	_look(p, hero.lerp(hero + Vector3(0, 1.1, 0), e) + Vector3(0, 0, -2.0 * (1.0 - e)))


func _orbit(hero: Vector3, u: float) -> void:
	var a := deg_to_rad(lerpf(215.0, 140.0, _ease(u)))
	var r := lerpf(3.9, 3.3, u)
	cam.fov = 40.0
	_look(hero + Vector3(sin(a) * r, 0.7, cos(a) * r), hero + Vector3(0, 1.05, 0))


func _lead(hero: Vector3, u: float) -> void:
	# Camera backs away ahead of the hero, low to the ground; the hero gains on it.
	var start := Vector3(0.9, 0.45, -3.4)
	var p := Vector3(start.x, 0, start.z - 1.65 * u * 4.0)
	cam.fov = 38.0
	_look(Vector3(p.x, hero.y + start.y, p.z), hero + Vector3(0, 0.9, 0))


func _side_track(hero: Vector3, delta: float) -> void:
	var v := Vector3(player.velocity.x, 0, player.velocity.z)
	if v.length() > 0.2:
		var right := v.normalized().cross(Vector3.UP)
		_side = right if _side == Vector3.ZERO else _side.slerp(right, 1.0 - exp(-2.0 * delta))
	cam.fov = 35.0
	_look(hero + _side * 5.0 + Vector3(0, 1.2, 0), hero + Vector3(0, 1.0, 0))


func _crane(hero: Vector3, u: float) -> void:
	# Rise up behind the hero and look past them toward the low sun.
	var v := Vector3(player.velocity.x, 0, player.velocity.z)
	if v.length() > 0.3:
		_heading = _heading.slerp(v.normalized(), 0.05).normalized()
	var e := _ease(u)
	var end := hero - _heading * 8.0 + Vector3(0, 3.5, 0)
	var p := _crane_from.origin.lerp(end, e)
	var target := (hero + Vector3(0, 1.0, 0)).lerp(hero + _heading * 14.0 + Vector3(0, 1.5, 0), e)
	cam.fov = lerpf(70.0, 50.0, e)
	_look(p, target)


# --- helpers ---------------------------------------------------------------------------------

func _drive_hero() -> void:
	var dir := Vector3.ZERO
	if t >= WALK_START and t < WALK_STOP and _wp < ROUTE.size():
		var here := Vector2(player.global_position.x, player.global_position.z)
		if here.distance_to(ROUTE[_wp]) < 1.0:
			_wp += 1
		if _wp < ROUTE.size():
			var to := ROUTE[_wp] - here
			dir = Vector3(to.x, 0, to.y).normalized()
	if dir != Vector3.ZERO:
		_steer = _steer.slerp(dir, 0.08).normalized()
		dir = _steer
	# Analog presses through the same actions the keyboard uses (player camera faces -Z).
	_press("move_right", dir.x)
	_press("move_left", -dir.x)
	_press("move_back", dir.z)
	_press("move_forward", -dir.z)


func _press(action: String, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _keep_above_ground() -> void:
	var p := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 50, p.z), Vector3(p.x, -10, p.z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit and p.y < hit.position.y + 0.3:
		var target := p + -cam.global_basis.z
		cam.global_position.y = hit.position.y + 0.3
		cam.look_at(target + Vector3(0, hit.position.y + 0.3 - p.y, 0))


func _look(pos: Vector3, target: Vector3) -> void:
	cam.global_position = pos
	cam.look_at(target)


func _u(a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


func _bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, u: float) -> Vector3:
	var v := 1.0 - u
	return a * v * v * v + b * 3.0 * v * v * u + c * 3.0 * v * u * u + d * u * u * u
