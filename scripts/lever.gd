extends Node3D
## Hebel zum Umlegen. Steht der Spieler im Bereich (Area), erscheint ein Hinweis; mit
## "interact" kippt das Modell (Model) und das Signal `pulled` geht los.
## Level 3: Der Hebel in der Krone des großen Baums stoppt die Flut (level_3_flow.gd).

signal pulled

@export var hint: String = "%s: Hebel umlegen"
@export var pull_angle_deg: float = -70.0   ## Drehung um Z beim Umlegen

@onready var _area: Area3D = $Area
@onready var _model: Node3D = $Model

var is_pulled := false
var _player_near := false


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	GameState.input_device_changed.connect(func(_gamepad: bool) -> void: _show_hint())


func _unhandled_input(event: InputEvent) -> void:
	if is_pulled or not _player_near or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	pull()


## Legt den Hebel um (auch aus einer Cutscene heraus aufrufbar).
func pull(animated: bool = true) -> void:
	if is_pulled:
		return
	is_pulled = true
	GameState.show_message("")
	var end := _model.rotation.z + deg_to_rad(pull_angle_deg)
	if animated:
		create_tween().tween_property(_model, "rotation:z", end, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_model.rotation.z = end
	pulled.emit()


func _show_hint() -> void:
	if _player_near and not is_pulled:
		GameState.show_message(hint % GameState.action_label("interact") if hint.contains("%s") else hint)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		_show_hint()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		if not is_pulled:
			GameState.show_message("")
