extends SceneTree
## Prüft Hauptmenü, Pausenmenü und die Grafikstufen; misst die FPS je Stufe.
## godot --path . --windowed --resolution 1280x720 --script res://tools/test_menu.gd
## Screenshots: screenshots/menu_*.png. Die gespeicherten Einstellungen bleiben unverändert.

var failures := 0


func check(ok: bool, text: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + text)
	if not ok:
		failures += 1


func frames(n: int) -> void:
	for i in n:
		await process_frame


func shot(file: String) -> void:
	await frames(3)
	root.get_texture().get_image().save_png("res://screenshots/%s.png" % file)


func fps_over(seconds: float) -> float:
	var start := Time.get_ticks_usec()
	var count := 0
	while Time.get_ticks_usec() - start < seconds * 1000000.0:
		await process_frame
		count += 1
	return count / ((Time.get_ticks_usec() - start) / 1000000.0)


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var settings = root.get_node("GameSettings")
	var menu = root.get_node("Menu")
	var original: String = settings.quality
	var original_full: bool = settings.fullscreen
	settings.fullscreen = false   # nur für den Test, wird nicht gespeichert
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)   # echte FPS messen

	change_scene_to_file("res://scenes/main_menu.tscn")
	await frames(30)
	check(menu.mode == menu.Mode.MAIN, "Hauptmenü erscheint")
	check(not paused, "Hauptmenü pausiert das Spiel nicht")
	check(not root.get_node("GameState/HUD").visible, "HUD ist im Hauptmenü ausgeblendet")
	await shot("menu_main")
	menu._show_page("options")
	await shot("menu_options")
	menu._show_page("main")

	# Spiel starten führt zum Prolog
	menu._start_game()
	await frames(20)
	check(current_scene.scene_file_path == "res://scenes/prolog.tscn", "Spiel starten öffnet den Prolog")
	check(menu.mode == menu.Mode.NONE, "Menü ist danach geschlossen")

	# Level 2: Pausenmenü und Grafikstufen
	change_scene_to_file("res://scenes/level_2.tscn")
	await frames(30)
	var env: Environment = current_scene.find_children("*", "WorldEnvironment", true, false)[0].environment
	settings.quality = "high"
	settings.apply_all()
	await frames(10)
	check(env.volumetric_fog_enabled and env.ssao_enabled, "Hoch: Volumen-Nebel und SSAO an")
	var fps_high := await fps_over(4.0)
	settings.quality = "low"
	settings.apply_all()
	await frames(10)
	check(not env.volumetric_fog_enabled and not env.ssao_enabled and not env.ssil_enabled, "Niedrig: teure Effekte aus")
	check(is_equal_approx(root.scaling_3d_scale, 0.58), "Niedrig: geringere 3D-Auflösung")
	var fps_low := await fps_over(4.0)
	print("FPS Level 2  Hoch: %.0f   Niedrig: %.0f" % [fps_high, fps_low])
	settings.quality = "high"
	settings.apply_all()
	await frames(5)
	check(env.volumetric_fog_enabled and env.ssao_enabled, "Zurück auf Hoch stellt die Effekte wieder her")

	var event := InputEventAction.new()
	event.action = "pause"
	event.pressed = true
	Input.parse_input_event(event)
	await frames(5)
	check(menu.mode == menu.Mode.PAUSE and paused, "Pause-Taste öffnet das Pausenmenü und pausiert")
	await shot("menu_pause")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await frames(5)
	check(menu.mode == menu.Mode.NONE and not paused, "Esc schließt das Pausenmenü wieder")

	settings.quality = original
	settings.fullscreen = original_full
	settings.apply_all()
	print("MENU TEST FAILURES: %d" % failures)
	quit(failures)
