extends Node3D
## Käfig mit dem gefangenen Dorfbewohner (Begegnung in Level 2).
## Steht der Spieler davor, erscheint ein Hinweis; mit "interact" wird der Gefangene befreit.
## Er tritt dann aus dem Käfig (Marker FreedSpot) und bleibt dort stehen. Das Flag
## "villager_freed" im GameState merkt sich die Begegnung – daran hängen z. B. das Portal
## und die Trinkflasche des Levels.

@export var hint: String = "%s drücken, um den Gefangenen zu befreien"
@export_multiline var freed_message: String = "„Danke, Fremder! Nimm meine Trinkflasche –\ndas Portal steht dir jetzt offen.“"
@export var freed_flag: String = "villager_freed"

@onready var _area: Area3D = $Area
@onready var _prisoner: Node3D = $Prisoner
@onready var _freed_spot: Marker3D = $FreedSpot

var _player_near := false


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	GameState.input_device_changed.connect(func(_gamepad: bool) -> void: _show_hint())
	if GameState.has_flag(freed_flag):
		_prisoner.transform = _freed_spot.transform * Transform3D(Basis.from_scale(_prisoner.scale), Vector3.ZERO)
	var player := _prisoner.find_children("*", "AnimationPlayer", true, false)
	if not player.is_empty() and (player[0] as AnimationPlayer).has_animation(&"Idle"):
		(player[0] as AnimationPlayer).get_animation(&"Idle").loop_mode = Animation.LOOP_LINEAR
		(player[0] as AnimationPlayer).play(&"Idle")


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and event.is_action_pressed("interact") and not GameState.has_flag(freed_flag):
		get_viewport().set_input_as_handled()
		GameState.set_flag(freed_flag)
		_step_out()
		GameState.flash_message(freed_message, 4.5)


## Der Befreite geht aus dem Käfig an seinen Platz daneben.
func _step_out() -> void:
	var target := _freed_spot.transform * Transform3D(Basis.from_scale(_prisoner.scale), Vector3.ZERO)
	var tween := create_tween()
	tween.tween_property(_prisoner, "transform", target, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _show_hint() -> void:
	if _player_near and not GameState.has_flag(freed_flag):
		GameState.show_message(hint % GameState.action_label("interact") if hint.contains("%s") else hint)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		_show_hint()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		if not GameState.has_flag(freed_flag):
			GameState.show_message("")
