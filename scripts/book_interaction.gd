extends Node3D
## Interaktion mit dem alten Buch auf dem Podest: Steht der Spieler davor,
## erscheint ein Hinweis, mit "interact" (E) wird das Buch geöffnet.
## Beim ersten Lesen werden die Flags "book_found" und "book_read" gesetzt.

@export var hint: String = "E drücken, um das Buch zu lesen"

@onready var _area: Area3D = $Area
@onready var _glow: OmniLight3D = $Glow

var _player_near := false


func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	Book.closed.connect(_on_book_closed)
	_glow.visible = not GameState.has_flag("book_read")


func _unhandled_input(event: InputEvent) -> void:
	if _player_near and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		GameState.show_message("")
		var first_time := not GameState.has_flag("book_found")
		GameState.set_flag("book_found")
		Book.open(0 if first_time else -1)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near = true
		GameState.show_message(hint)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_near = false
		GameState.show_message("")


func _on_book_closed() -> void:
	if not _player_near:
		return
	if not GameState.has_flag("book_read"):
		GameState.set_flag("book_read")
		_glow.visible = false
		GameState.flash_message("Das Portal ist erwacht!\n(B: Buch jederzeit öffnen)", 3.0)
	else:
		GameState.show_message(hint)
