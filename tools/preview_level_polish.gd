extends SceneTree
## Capture each dressed area using the actual renderer, then exit.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var shots := [
		["level_1", Vector3(0,5,-70), Vector3(0,0,-88)],
		["level_2", Vector3(20,10,-196), Vector3(5,0,-211)],
		["level_3", Vector3(28,20,-96), Vector3(5,10,-128)],
		["level_3", Vector3(27,14,-102), Vector3(10,6,-120), "flood"],
		["level_3", Vector3(5,4,4), Vector3(0,0,-8), "swamp"],
		["level_3", Vector3(11,8,-58), Vector3(0,0,-82), "islands"],
		["level_1", Vector3(7,4,21), Vector3(0,0,5), "beach"],
	]
	for shot in shots:
		if not OS.get_cmdline_user_args().is_empty() and shot[0] != OS.get_cmdline_user_args()[0]:
			continue
		root.get_node("GameState").clear_checkpoint()
		var scene = load("res://scenes/%s.tscn" % shot[0]).instantiate()
		for area in scene.find_children("*", "Area3D", true, false):
			area.collision_mask = 0
		(scene.get_node("Player") as CharacterBody3D).collision_layer = 0
		root.add_child(scene)
		current_scene = scene
		if shot.size() > 3 and shot[3] == "flood":
			scene.get_node("Ablauf")._open_sluice_now()
			scene.get_node("Wasser").water_level = 6.0
			scene.get_node("Wasser")._apply()
		var player := get_first_node_in_group("player") as Node3D
		player.set_physics_process(false)
		var cam := Camera3D.new()
		scene.add_child(cam)
		cam.global_position = shot[1]
		cam.look_at(shot[2])
		cam.current = true
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		var suffix: String = "_" + shot[3] if shot.size() > 3 else ""
		root.get_texture().get_image().save_png("res://screenshots/polish_%s%s.png" % [shot[0], suffix])
		scene.queue_free()
		await process_frame
	quit()
