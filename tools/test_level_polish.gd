extends SceneTree
## Run: godot --headless --path . --script res://tools/test_level_polish.gd
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	var state := root.get_node("GameState")
	state.clear_checkpoint()
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	ground.add_child(shape)
	ground.position.y = -0.5
	arena.add_child(ground)
	var player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0, 0.1, -3)
	arena.add_child(player)
	await frames(20)
	check(player.is_on_floor(), "Player settles on floor")
	check(player.movement_loudness() == 0.0, "Stationary player is silent")
	shape.disabled = true
	await frames(2)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	check(player.velocity.y > 3.0, "Coyote jump works after leaving floor")
	shape.disabled = false
	player.global_position = Vector3(0, 0.3, -3)
	player.velocity = Vector3(0,-4,0)
	player.set("_coyote_left", 0.0)
	player.set("jump_time", -1.0)
	await frames(1)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(5)
	check(player.velocity.y > 2.0, "Buffered jump fires on landing")
	player.global_position = Vector3(0, 0.1, -3)
	player.velocity = Vector3.ZERO
	await frames(60)
	var guard = load("res://scenes/village/guard.tscn").instantiate()
	arena.add_child(guard)
	await frames(40)
	check(guard.detection == 0.0, "Guard cannot hear a stationary player behind it")
	guard.hear_noise(player.global_position, 8.0)
	await frames(2)
	check(guard.awareness == guard.Awareness.INVESTIGATE, "Noise prompts investigation")
	check(not guard.get("_caught"), "Hearing alone does not capture the player")
	guard.rotation.y = 0.0
	player.global_position = Vector3(0,0.1,8)
	guard.awareness = guard.Awareness.PATROL
	guard.detection = 0.95
	await frames(8)
	check(guard.awareness == guard.Awareness.CHASE and not guard.get("_caught"), "Visual detection starts pursuit instead of instant capture")
	player.global_position = Vector3(30,0.1,-25)
	await frames(2)
	check(guard.awareness == guard.Awareness.INVESTIGATE, "Lost sight sends guard to last known position")
	guard.queue_free()
	await frames(2)
	var monkey = load("res://scripts/sleeping_monkey.gd").new()
	check(monkey._loudness(player) == 0.0, "Stationary player does not wake monkeys")
	monkey.free()
	arena.queue_free()
	await frames(3)
	state.clear_checkpoint()
	var level = load("res://scenes/level_3.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(4)
	var flow = level.get_node("Ablauf")
	flow._open_sluice_now()
	check(level.get_node("Lichtung/SchleusenWasser").visible, "Opening sluice enables flow")
	var climber = get_first_node_in_group("player")
	climber.global_position = Vector3(0,18.1,-125.4)
	climber.velocity = Vector3.ZERO
	var cutscene = flow.get_node(flow.end_cutscene)
	flow.get_node(flow.crown_lever).pull()
	check(cutscene.is_playing, "Crown lever immediately starts ending cutscene")
	check(not climber.is_physics_processing(), "Cutscene takes over player controls immediately")
	var animation = cutscene.get_node("AnimationPlayer")
	animation.advance(animation.get_animation(cutscene.animation).length + 0.1)
	await frames(2)
	var end_position: Vector3 = flow.get_node(flow.end_spawn).global_position
	check(climber.global_position.distance_to(end_position) < 0.15, "Normal cutscene ending places player at tree base")
	check(climber.is_physics_processing(), "Controls return after ending")
	check(state.checkpoint_id == "l3_ende", "Ending saves ground checkpoint")
	check(not level.has_node("AbstiegsLiane"), "No descent rope is created")
	check(not level.get_node("Lichtung/SchleusenWasser").visible, "Ending disables waterfall")
	check(is_equal_approx(level.get_node("Lichtung/Schleusentor").position.y, flow.get("_gate_closed_y")), "Ending closes gate")
	check(not level.get_node("Teil1_Sumpf").find_children("Grass_*", "MultiMeshInstance3D", false, false).is_empty(), "Swamp paths have grass")
	check(not level.get_node("Lichtung").find_children("Grass_*", "MultiMeshInstance3D", false, false).is_empty(), "Clearing has grass")
	level.queue_free()
	await frames(3)
	level = load("res://scenes/level_3.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(4)
	check(not level.get_node("Lichtung/SchleusenWasser").visible and not level.has_node("AbstiegsLiane"), "Completed-level reload keeps ending state without rope")
	level.queue_free()
	await frames(3)
	state.clear_checkpoint()
	level = load("res://scenes/level_3.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(2)
	flow = level.get_node("Ablauf")
	flow._open_sluice_now()
	climber = get_first_node_in_group("player")
	climber.global_position = Vector3(0,18.1,-125.4)
	flow.get_node(flow.crown_lever).pull()
	cutscene = flow.get_node(flow.end_cutscene)
	cutscene.get_node("AnimationPlayer").stop()
	cutscene._end()
	await frames(3)
	check(climber.global_position.distance_to(flow.get_node(flow.end_spawn).global_position) < 0.15 and state.checkpoint_id == "l3_ende", "Skipped cutscene also places player at ground checkpoint")
	check(is_equal_approx(level.get_node("Lichtung/Schleusentor").position.y, flow.get("_gate_closed_y")), "Skipping cancels gate tween without reopening gate")
	level.queue_free()
	await frames(3)
	state.set_checkpoint("l3_abstieg", Vector3(0,18.1,-125.4))
	level = load("res://scenes/level_3.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(4)
	check(state.checkpoint_id == "l3_ende" and get_first_node_in_group("player").global_position.y < 1.0, "Legacy descent checkpoint migrates to tree base")
	level.queue_free()
	await frames(3)
	print("POLISH TEST FAILURES: ", failures)
	quit(1 if failures else 0)
