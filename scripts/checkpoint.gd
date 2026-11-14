extends Node3D
## Checkpoint (Fahnenmast). Läuft der Spieler hindurch, startet er nach einem Tod
## hier statt am Levelanfang. Im Spiel ist er unsichtbar (nur die Meldung erscheint);
## im Editor bleibt der Mast zum Platzieren zu sehen. Mit show_marker sieht man ihn
## auch im Spiel, ein aktiver Checkpoint leuchtet dann.

## Muss pro Level eindeutig sein – sonst gilt jeder gleichnamige Checkpoint als aktiv.
@export var checkpoint_id: String = ""
## Fahnenmast und Licht auch im Spiel anzeigen.
@export var show_marker: bool = false

@onready var _area: Area3D = $Area
@onready var _spawn_point: Marker3D = $SpawnPoint
@onready var _light: OmniLight3D = $ActiveLight
@onready var _model: Node3D = $Model


func _ready() -> void:
	if checkpoint_id == "":
		checkpoint_id = str(get_path())
	_model.visible = show_marker
	_area.body_entered.connect(_on_body_entered)
	GameState.checkpoint_changed.connect(_on_checkpoint_changed)
	_on_checkpoint_changed(GameState.checkpoint_id)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if GameState.set_checkpoint(checkpoint_id, _spawn_point.global_position) and show_marker:
		GameState.flash_message("Checkpoint erreicht", 1.5)


func _on_checkpoint_changed(active_id: String) -> void:
	_light.visible = show_marker and active_id == checkpoint_id
