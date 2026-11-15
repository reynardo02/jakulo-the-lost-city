extends Node3D
## Grundgerüst für Cutscenes.
## Eine Cutscene ist eine Szene mit diesem Script, einer eigenen Kamera ("Camera") und einem
## AnimationPlayer als Zeitleiste. Die Animation `animation` bewegt die Kamera und ruft über
## Methoden-Spuren Funktionen auf – hier z. B. say() für Untertitel oder Methoden anderer
## Knoten im Level (Pfad relativ zu diesem Knoten).
##
## play() sperrt die Steuerung des Spielers, blendet schwarze Balken ein, spielt die Zeitleiste
## ab und gibt danach alles wieder frei. Mit SPRINGEN oder BENUTZEN lässt sie sich überspringen.
## Wer auf das Ende reagieren muss (auch beim Überspringen), hängt sich an `finished`.

signal started
signal finished

@export var animation: StringName = &"cutscene"
@export var skippable: bool = true
@export var bar_height: float = 90.0   ## Höhe der schwarzen Balken oben und unten

@onready var _camera: Camera3D = $Camera
@onready var _anim: AnimationPlayer = $AnimationPlayer

var is_playing := false

var _player: Node3D
var _previous_camera: Camera3D
var _ui: CanvasLayer
var _speaker: Label
var _text: Label
var _skip_ready := false


## Startet die Cutscene. Kehrt sofort zurück; das Ende meldet das Signal `finished`.
func play() -> void:
	if is_playing:
		return
	is_playing = true
	_skip_ready = false
	_player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(_player):
		_player.set_physics_process(false)   # keine Steuerung; Wachen ignorieren ihn so lange
		if _player is CharacterBody3D:
			(_player as CharacterBody3D).velocity = Vector3.ZERO
	GameState.show_message("")
	_previous_camera = get_viewport().get_camera_3d()
	_camera.make_current()
	_build_ui()
	started.emit()
	_anim.play(animation)
	# der Tastendruck, der die Szene ausgelöst hat, soll sie nicht gleich überspringen
	get_tree().create_timer(0.6).timeout.connect(func() -> void: _skip_ready = true)
	await _anim.animation_finished
	_end()


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing or not skippable or not _skip_ready:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_anim.stop()
		_end()


func _end() -> void:
	if not is_playing:
		return
	is_playing = false
	if is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	if is_instance_valid(_player):
		_player.set_physics_process(true)
	if _ui:
		_ui.queue_free()
		_ui = null
	finished.emit()


# ---------- für Methoden-Spuren der Zeitleiste ----------

## Zeigt eine Zeile Untertitel. Leerer Sprecher = Erzähltext.
func say(speaker: String, text: String) -> void:
	if _ui:
		_speaker.text = speaker
		_text.text = text


func clear_text() -> void:
	say("", "")


# ---------- Balken und Untertitel ----------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 15
	add_child(_ui)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, bar_height)
		if not top:
			bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
		bar.size.y = bar_height
		_ui.add_child(bar)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -bar_height - 18.0
	box.alignment = BoxContainer.ALIGNMENT_END
	_ui.add_child(box)
	_speaker = _make_label(26, Color(1.0, 0.85, 0.45))
	_text = _make_label(32, Color.WHITE)
	box.add_child(_speaker)
	box.add_child(_text)

	if skippable:
		var skip := _make_label(18, Color(1, 1, 1, 0.6))
		skip.text = "%s: überspringen" % GameState.action_label("jump")
		skip.autowrap_mode = TextServer.AUTOWRAP_OFF   # sonst bricht der Text in der schmalen Ecke Buchstabe für Buchstabe um
		skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		skip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# rechts im unteren Balken
		skip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		skip.offset_top = -bar_height
		skip.offset_right = -24.0
		_ui.add_child(skip)


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10)
	return label
