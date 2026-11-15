extends Node3D
## Käfig mit dem gefangenen Dorfbewohner (Begegnung in Level 2).
## Steht der Spieler davor, erscheint ein Hinweis; mit "interact" wird der Gefangene befreit.
## Er tritt dann aus dem Käfig (Marker FreedSpot) und bleibt dort stehen. Das Flag
## "villager_freed" im GameState merkt sich die Begegnung – daran hängen z. B. das Portal
## und die Trinkflasche des Levels.
##
## Ist `cutscene` gesetzt, läuft die Befreiung als Cutscene: Deren Zeitleiste ruft step_out()
## und complete() selbst auf. Ohne Cutscene passiert beides sofort, mit einer kurzen Meldung.

@export var hint: String = "%s drücken, um den Gefangenen zu befreien"
@export_multiline var freed_message: String = "„Danke, Fremder! Nimm meine Trinkflasche –\ndas Portal steht dir jetzt offen.“"
@export var freed_flag: String = "villager_freed"
@export var cutscene: NodePath   ## Knoten mit scripts/cutscene.gd, der die Befreiung zeigt (optional)

@onready var _area: Area3D = $Area
@onready var _prisoner: Node3D = $Prisoner
@onready var _freed_spot: Marker3D = $FreedSpot

var _player_near := false
var _busy := false   # Cutscene läuft
var _step_tween: Tween


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	GameState.input_device_changed.connect(func(_gamepad: bool) -> void: _show_hint())
	if GameState.has_flag(freed_flag):
		_prisoner.transform = _freed_transform()
	var player := _prisoner.find_children("*", "AnimationPlayer", true, false)
	if not player.is_empty() and (player[0] as AnimationPlayer).has_animation(&"Idle"):
		(player[0] as AnimationPlayer).get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
		(player[0] as AnimationPlayer).play(&"Idle")


func _unhandled_input(event: InputEvent) -> void:
	if _busy or not _player_near or GameState.has_flag(freed_flag) or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	var scene := get_node_or_null(cutscene)
	if scene and scene.has_method("play"):
		_busy = true
		scene.finished.connect(_on_cutscene_finished, CONNECT_ONE_SHOT)
		scene.play()
	else:
		complete()
		step_out()
		GameState.flash_message(freed_message, 4.5)


func _freed_transform() -> Transform3D:
	return _freed_spot.transform * Transform3D(Basis.from_scale(_prisoner.scale), Vector3.ZERO)


## Der Befreite geht aus dem Käfig an seinen Platz daneben.
func step_out() -> void:
	_step_tween = create_tween()
	_step_tween.tween_property(_prisoner, "transform", _freed_transform(), 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Merkt sich die Begegnung: Portal und Trinkflasche werden damit verfügbar.
func complete() -> void:
	GameState.set_flag(freed_flag)


## Auch nach dem Überspringen muss alles im Endzustand sein.
func _on_cutscene_finished() -> void:
	_busy = false
	if _step_tween:
		_step_tween.kill()
	_prisoner.transform = _freed_transform()
	complete()


func _show_hint() -> void:
	if _player_near and not _busy and not GameState.has_flag(freed_flag):
		GameState.show_message(hint % GameState.action_label("interact") if hint.contains("%s") else hint)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		_show_hint()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		if not _busy and not GameState.has_flag(freed_flag):
			GameState.show_message("")
