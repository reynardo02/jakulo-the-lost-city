extends Node3D
## Magisches Portal am Levelende: Betritt der Spieler die PortalArea, ist das Level geschafft.
## Mit required_flag bleibt es verschlossen (dunkel), bis das Flag im GameState gesetzt ist.

## Szene des nächsten Levels. Leer lassen, solange es noch kein Folgelevel gibt.
@export_file("*.tscn") var next_scene: String = ""
## GameState-Flag, das das Portal öffnet (z. B. "book_read"). Leer = immer offen.
@export var required_flag: String = ""
@export var locked_hint: String = "Das Portal ist verschlossen.\nVielleicht verrät das alte Buch mehr."

@onready var _portal_area: Area3D = $PortalArea
@onready var _void: Node3D = $Void
@onready var _glow: OmniLight3D = $Glow


func _ready() -> void:
	_portal_area.body_entered.connect(_on_body_entered)
	GameState.flag_set.connect(_on_flag_set)
	_update_active()


func is_active() -> bool:
	return required_flag == "" or GameState.has_flag(required_flag)


func _update_active() -> void:
	_void.visible = is_active()
	_glow.visible = is_active()


func _on_flag_set(id: String) -> void:
	if id == required_flag:
		_update_active()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if is_active():
		GameState.level_completed(body, next_scene)
	else:
		GameState.flash_message(locked_hint, 2.5)
