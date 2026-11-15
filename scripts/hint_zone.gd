extends Area3D
## Zeigt einen Hinweis, solange der Spieler im Bereich steht.
## "%s" im Text wird durch die Taste der Aktion `action` ersetzt (passend zu Tastatur oder Controller).

@export_multiline var hint: String = ""
@export var action: String = ""

var _player_inside := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.input_device_changed.connect(func(_gamepad: bool) -> void: _show())


func _show() -> void:
	if _player_inside:
		GameState.show_message(hint % GameState.action_label(action) if hint.contains("%s") else hint)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_show()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		GameState.show_message("")
