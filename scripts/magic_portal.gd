extends Node3D
## Magisches Portal am Levelende: Betritt der Spieler die PortalArea, ist das Level geschafft.

## Szene des nächsten Levels. Leer lassen, solange es noch kein Folgelevel gibt.
@export_file("*.tscn") var next_scene: String = ""

@onready var _portal_area: Area3D = $PortalArea


func _ready() -> void:
	_portal_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameState.level_completed(body, next_scene)
