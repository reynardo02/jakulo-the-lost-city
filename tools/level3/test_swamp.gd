extends SceneTree
## Prüft die neuen Sumpfinseln und die steinwerfenden Affen in Level 3.
## godot --headless --path . --script res://tools/level3/test_swamp.gd

var failures := 0


func check(ok: bool, text: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + text)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var state = root.get_node("GameState")
	state.clear_checkpoint()
	var level = load("res://scenes/level_3.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(6)
	var space = level.get_world_3d().direct_space_state

	# Unter jeder früheren Kachelfläche liegt weiterhin fester Boden auf Höhe 0
	var rects := {
		"InselA": [Vector2(-4, -10), Vector2(4, 6)],
		"Inselchen": [Vector2(6, -7), Vector2(10, -3)],
		"InselB": [Vector2(-8, -41), Vector2(8, -25)],
		"InselC": [Vector2(-4, -61), Vector2(4, -49)],
		"InselD1": [Vector2(-8, -87.7), Vector2(8, -76)],
		"InselD2": [Vector2(-8, -102.5), Vector2(8, -90.8)],
	}
	for island_name in rects:
		var lo: Vector2 = rects[island_name][0]
		var hi: Vector2 = rects[island_name][1]
		var worst := 0.0
		var missing := 0
		for ix in 9:
			for iz in 9:
				var x: float = lerpf(lo.x + 0.05, hi.x - 0.05, ix / 8.0)
				var z: float = lerpf(lo.y + 0.05, hi.y - 0.05, iz / 8.0)
				var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 3, z), Vector3(x, -3, z), 1))
				if hit.is_empty():
					missing += 1
				else:
					worst = maxf(worst, absf(hit.position.y))
		check(missing == 0 and worst < 0.08, "%s: Boden überall im alten Kachelbereich (fehlt %d, max. Abweichung %.3f m)" % [island_name, missing, worst])

	# Das flache Wasser zwischen D1 und D2 bleibt ohne Inselboden darüber
	var shallow = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0, 3, -89.25), Vector3(0, -3, -89.25), 1))
	check(not shallow.is_empty() and shallow.position.y < -0.5, "Flaches Wasser zwischen den Inseln bleibt (Grund %.2f)" % (shallow.position.y if shallow else 99.0))

	# Spieler steht stabil auf einer Insel
	var player = get_first_node_in_group("player")
	player.global_position = Vector3(1, 0.5, -55)
	player.velocity = Vector3.ZERO
	await frames(40)
	check(player.is_on_floor() and absf(player.global_position.y) < 0.1, "Spieler steht auf Insel C (y = %.3f)" % player.global_position.y)

	# Gras wächst auf den Inseln
	var grass := 0
	for mm in level.get_node("Teil1_Sumpf").find_children("Grass_*", "MultiMeshInstance3D", false, false):
		grass += mm.multimesh.instance_count
	check(grass > 5000, "Gras auf den Sumpfinseln (%d Halme)" % grass)

	# Affe: aufwecken, er greift einen Stein und wirft; ein stehender Spieler wird getroffen
	var monkey = level.get_node("Teil1_Sumpf/Affe2")
	player.global_position = monkey.global_position + Vector3(5, 0.3, 0)
	player.velocity = Vector3.ZERO
	await frames(10)
	state.lives = 3
	var lives_before: int = state.lives
	monkey.wake()
	var saw_held := false
	var saw_flight := false
	for i in 600:
		await physics_frame
		player.velocity = Vector3.ZERO
		if monkey._held.visible:
			saw_held = true
		if not monkey._stones.is_empty():
			saw_flight = true
		if state.lives < lives_before:
			break
	check(saw_held, "Affe hebt einen Stein auf (Stein in der Hand)")
	check(saw_flight, "Affe wirft den Stein")
	check(state.lives == lives_before - 1, "Stehender Spieler wird getroffen und verliert ein Leben")
	var thrown_after_hit := false
	for i in 400:
		await physics_frame
		if monkey._state == monkey.State.THROW and not monkey._released:
			thrown_after_hit = true
	check(not thrown_after_hit, "Nach einem Treffer gibt der Affe Ruhe")
	check(state.lives == lives_before - 1, "Kein zweiter Treffer direkt danach (auch nicht vom Nachbarn)")
	for i in 600:
		await physics_frame
		if monkey._state == monkey.State.ASLEEP:
			break
	check(monkey._state == monkey.State.ASLEEP, "Affe schläft danach wieder ein")

	# Ausweichen: ein seitlich laufender Spieler wird nicht getroffen
	state.lives = 3
	await frames(200)   # Schonfrist nach dem letzten Treffer abwarten
	var monkey2 = level.get_node("Teil1_Sumpf/Affe1")
	player.global_position = Vector3(2, 0.3, -5)
	await frames(10)
	lives_before = state.lives
	monkey2.wake()
	var dir := 1.0
	var threw := false
	for i in 500:
		await physics_frame
		if not monkey2._stones.is_empty():
			threw = true
		# quer zur Wurfrichtung hin und her laufen
		player.global_position.z += 4.5 * dir / 60.0
		if player.global_position.z < -9.0:
			dir = 1.0
		elif player.global_position.z > 1.0:
			dir = -1.0
	check(threw, "Zweiter Affe wirft ebenfalls")
	check(state.lives == lives_before, "Wer sich bewegt, kann den Steinen ausweichen")

	print("SWAMP TEST FAILURES: %d" % failures)
	quit(failures)
