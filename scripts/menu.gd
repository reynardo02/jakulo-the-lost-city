extends CanvasLayer
## Menü (Autoload "Menu"): Hauptmenü beim Spielstart und Pausenmenü im Spiel.
##
## - Hauptmenü (scenes/main_menu.tscn ruft show_main_menu() auf): Spiel starten, Optionen,
##   Steuerung, Beenden.
## - Pausenmenü: Esc bzw. die Options-Taste am Controller ("pause"). Fortsetzen, Optionen,
##   Steuerung, am Checkpoint neu starten, Hauptmenü, Beenden. Das Spiel ist solange pausiert.
## - Optionen: Grafik Niedrig/Hoch, Musik- und Effektlautstärke, Vollbild (Autoload GameSettings).
## Alles ist mit Maus, Tastatur und Controller bedienbar (ui_up/ui_down/ui_accept/ui_cancel).

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const START_SCENE := "res://scenes/prolog.tscn"

const PAPER := Color(0.93, 0.86, 0.7)
const PAPER_DARK := Color(0.8, 0.7, 0.5)
const INK := Color(0.24, 0.15, 0.08)
const GOLD := Color(0.85, 0.62, 0.15)

enum Mode { NONE, MAIN, PAUSE }

var mode := Mode.NONE

var _root: Control
var _dim: ColorRect
var _holder: MarginContainer
var _panel: PanelContainer
var _rule: ColorRect
var _title: Label
var _pages := {}            # Name -> Control
var _main_buttons: VBoxContainer
var _quality_buttons := {}  # GameSettings.QUALITY_* -> Button
var _quality_info: Label
var _music_slider: HSlider
var _sound_slider: HSlider
var _fullscreen: CheckButton
var _mouse_before := Input.MOUSE_MODE_CAPTURED
var _theme: Theme


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()
	GameSettings.changed.connect(_sync_options)


func is_open() -> bool:
	return mode != Mode.NONE


# ---------- Öffnen und Schließen ----------

func show_main_menu() -> void:
	mode = Mode.MAIN
	get_tree().paused = false
	_set_hud(false)
	_dim.color = Color(0.02, 0.03, 0.02, 0.35)
	_holder.add_theme_constant_override("margin_left", 80)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_title.text = "Jakulo\nThe Lost City"
	_fill_main_buttons()
	_root.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page("main")


func open_pause() -> void:
	if mode != Mode.NONE:
		return
	mode = Mode.PAUSE
	_mouse_before = Input.mouse_mode
	get_tree().paused = true
	_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_holder.add_theme_constant_override("margin_left", 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title.text = "Pause"
	_fill_main_buttons()
	_root.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page("main")


func close() -> void:
	if mode == Mode.PAUSE:
		get_tree().paused = false
		Input.mouse_mode = _mouse_before
	mode = Mode.NONE
	_root.hide()


func _can_pause() -> bool:
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == MAIN_MENU_SCENE:
		return false
	if Book.is_open or get_tree().paused:
		return false
	return true


func _input(event: InputEvent) -> void:
	if mode == Mode.NONE:
		if event.is_action_pressed("pause") and _can_pause():
			open_pause()
			get_viewport().set_input_as_handled()
		return
	# Menü offen: das Spiel bekommt keine Eingaben
	if event.is_action_pressed("open_book"):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _pages["main"].visible:
			if mode == Mode.PAUSE:
				close()
		else:
			_show_page("main")


func _set_hud(visible_now: bool) -> void:
	var hud := GameState.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = visible_now


# ---------- Aktionen ----------

func _start_game() -> void:
	close()
	_set_hud(true)
	GameState.reset()
	get_tree().change_scene_to_file(START_SCENE)


func _restart_checkpoint() -> void:
	close()
	get_tree().reload_current_scene()


func _to_main_menu() -> void:
	close()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _quit() -> void:
	get_tree().quit()


# ---------- Aufbau ----------

func _build() -> void:
	_theme = _make_theme()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _theme
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	# Der Container passt das Panel bei jedem Seitenwechsel an den Inhalt an
	_holder = MarginContainer.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_holder)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 0)
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_holder.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 46)
	_title.add_theme_color_override("font_color", INK)
	column.add_child(_title)
	_rule = ColorRect.new()
	_rule.color = GOLD
	_rule.custom_minimum_size = Vector2(0, 3)
	column.add_child(_rule)

	# Hauptseite
	_main_buttons = VBoxContainer.new()
	_main_buttons.add_theme_constant_override("separation", 10)
	column.add_child(_main_buttons)
	_pages["main"] = _main_buttons

	# Optionen
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	column.add_child(options)
	_pages["options"] = options
	options.add_child(_heading("Grafik"))
	var quality_row := HBoxContainer.new()
	quality_row.add_theme_constant_override("separation", 10)
	options.add_child(quality_row)
	var group := ButtonGroup.new()
	for entry in [[GameSettings.QUALITY_LOW, "Niedrig"], [GameSettings.QUALITY_HIGH, "Hoch"]]:
		var b := Button.new()
		b.text = entry[1]
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var q: String = entry[0]
		b.pressed.connect(func() -> void: GameSettings.set_quality(q))
		quality_row.add_child(b)
		_quality_buttons[q] = b
	_quality_info = Label.new()
	_quality_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quality_info.custom_minimum_size = Vector2(440, 0)
	_quality_info.add_theme_font_size_override("font_size", 18)
	_quality_info.add_theme_color_override("font_color", Color(INK, 0.75))
	options.add_child(_quality_info)
	_fullscreen = CheckButton.new()
	_fullscreen.text = "Vollbild"
	_fullscreen.toggled.connect(func(on: bool) -> void: GameSettings.set_fullscreen(on))
	options.add_child(_fullscreen)
	options.add_child(_heading("Lautstärke"))
	_music_slider = _slider(options, "Musik", func(v: float) -> void: GameSettings.set_music_volume(v))
	_sound_slider = _slider(options, "Effekte", func(v: float) -> void: GameSettings.set_sound_volume(v))
	options.add_child(_back_button())

	# Steuerung
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	column.add_child(controls)
	_pages["controls"] = controls
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.custom_minimum_size = Vector2(640, 0)
	text.add_theme_color_override("default_color", INK)
	text.add_theme_font_size_override("normal_font_size", 18)
	text.add_theme_font_size_override("bold_font_size", 20)
	text.text = Book.CONTROLS_TEXT
	controls.add_child(text)
	controls.add_child(_back_button())
	_sync_options()


func _fill_main_buttons() -> void:
	for child in _main_buttons.get_children():
		_main_buttons.remove_child(child)
		child.queue_free()
	var entries: Array = []
	if mode == Mode.MAIN:
		entries = [["Spiel starten", _start_game], ["Optionen", _show_page.bind("options")],
			["Steuerung", _show_page.bind("controls")], ["Beenden", _quit]]
	else:
		entries = [["Fortsetzen", close], ["Optionen", _show_page.bind("options")],
			["Steuerung", _show_page.bind("controls")],
			["Am Checkpoint neu starten", _restart_checkpoint],
			["Hauptmenü", _to_main_menu], ["Spiel beenden", _quit]]
	for entry in entries:
		var b := Button.new()
		b.text = entry[0]
		b.pressed.connect(entry[1])
		_main_buttons.add_child(b)


func _show_page(page_name: String) -> void:
	for key in _pages:
		_pages[key].visible = key == page_name
	_title.visible = page_name == "main"
	_rule.visible = _title.visible
	# Fokus auf das erste Bedienelement, damit der Controller sofort funktioniert
	var first := _first_focusable(_pages[page_name])
	if first:
		first.call_deferred("grab_focus")


func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control and (child as Control).focus_mode == Control.FOCUS_ALL and (child as Control).visible:
			return child
		var inner := _first_focusable(child)
		if inner:
			return inner
	return null


func _sync_options() -> void:
	if _quality_buttons.is_empty():
		return
	for q in _quality_buttons:
		_quality_buttons[q].set_pressed_no_signal(GameSettings.quality == q)
	_quality_info.text = "Niedrig: ohne Volumen-Nebel, Umgebungsverdeckung und Lichtstreuung, einfachere Schatten, weniger Gras. Für mehr Bilder pro Sekunde." \
		if GameSettings.is_low() else "Hoch: alle Effekte, wie die Level gestaltet sind."
	_music_slider.set_value_no_signal(GameSettings.music_volume)
	_sound_slider.set_value_no_signal(GameSettings.sound_volume)
	_fullscreen.set_pressed_no_signal(GameSettings.fullscreen)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", INK)
	return label


func _slider(parent: Control, text: String, on_change: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(110, 0)
	label.add_theme_color_override("font_color", INK)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(260, 28)
	slider.focus_mode = Control.FOCUS_ALL
	slider.value_changed.connect(on_change)
	row.add_child(slider)
	return slider


func _back_button() -> Button:
	var b := Button.new()
	b.text = "Zurück"
	b.pressed.connect(_show_page.bind("main"))
	return b


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 24
	var panel := StyleBoxFlat.new()
	panel.bg_color = PAPER
	panel.border_color = PAPER_DARK
	panel.set_border_width_all(4)
	panel.set_corner_radius_all(10)
	panel.shadow_color = Color(0, 0, 0, 0.45)
	panel.shadow_size = 18
	theme.set_stylebox("panel", "PanelContainer", panel)

	var normal := StyleBoxFlat.new()
	normal.bg_color = PAPER_DARK
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = PAPER_DARK.lightened(0.15)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0, 0, 0, 0)
	focus.draw_center = false
	focus.border_color = GOLD
	focus.set_border_width_all(3)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = GOLD
	for type in ["Button", "CheckButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("focus", type, focus)
		theme.set_color("font_color", type, INK)
		theme.set_color("font_hover_color", type, INK)
		theme.set_color("font_pressed_color", type, INK)
		theme.set_color("font_hover_pressed_color", type, INK)
		theme.set_color("font_focus_color", type, INK)
	theme.set_color("font_color", "Label", INK)
	var slider_focus := focus.duplicate() as StyleBoxFlat
	theme.set_stylebox("focus", "HSlider", slider_focus)
	var track := StyleBoxFlat.new()
	track.bg_color = PAPER_DARK
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = GOLD
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	return theme
