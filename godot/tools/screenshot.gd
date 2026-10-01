# Renders world.tscn with the player at the origin and saves a frame from the player camera.
# Run (needs a display): godot --path . --script res://tools/screenshot.gd -- <out.png> [anim]
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://shot.png"
	var world: Node3D = (load("res://world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player: Node3D = (load("res://player.tscn") as PackedScene).instantiate()
	world.add_child(player)
	if args.size() > 1:
		var anim := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
		anim.play(args[1])
		anim.seek(0.25, true)
		anim.pause()
	_capture.call_deferred(out)


func _capture(out: String) -> void:
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var err := root.get_viewport().get_texture().get_image().save_png(out)
	print("saved %s (%s)" % [out, error_string(err)])
	quit(0)
