extends Node3D
## Checkpoint (Fahnenmast). Läuft der Spieler hindurch, startet er nach einem Tod
## hier statt am Levelanfang. Ein aktiver Checkpoint leuchtet.

## Muss pro Level eindeutig sein – sonst gilt jeder gleichnamige Checkpoint als aktiv.
@export var checkpoint_id: String = ""

@onready var _area: Area3D = $Area
@onready var _spawn_point: Marker3D = $SpawnPoint
@onready var _light: OmniLight3D = $ActiveLight


func _ready() -> void:
	if checkpoint_id == "":
		checkpoint_id = str(get_path())
	_area.body_entered.connect(_on_body_entered)
	GameState.checkpoint_changed.connect(_on_checkpoint_changed)
	_on_checkpoint_changed(GameState.checkpoint_id)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and GameState.set_checkpoint(checkpoint_id, _spawn_point.global_position):
		GameState.flash_message("Checkpoint erreicht", 1.5)


func _on_checkpoint_changed(active_id: String) -> void:
	_light.visible = active_id == checkpoint_id
