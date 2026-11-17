extends Node3D
## Steigendes Wasser (Level 3). Dieser Knoten ist die Wasseroberfläche: Er trägt die
## Wasserfläche (Surface) und eine KillZone knapp darunter und steigt mit dem Wasserstand.
##
## Alles, was schwimmt (Seerosen, Treibholz, Krokodile), hängt unter `floating_path` und wird
## jedes Physik-Bild direkt angehoben. Bewegliche Körper (AnimatableBody3D) übernehmen eine
## Bewegung ihres Elternknotens nämlich nicht in die Physik – deshalb nicht einfach als Kinder
## mitbewegen. Knoten mit einer Eigenschaft `water_offset` (sinking_lily_pad.gd,
## drifting_log.gd) bekommen den Wasserstand dort hinein, alle anderen werden verschoben.
##
## Das Tempo hängt an Abschnitten statt an einer Uhr: Erreicht der Spieler den Checkpoint
## checkpoint_ids[i], steigt das Wasser mit stage_speeds[i] bis stage_levels[i] und wartet
## dort – knapp unter dem nächsten Checkpoint. Nach einem Tod lädt das Level neu: Das Wasser
## startet dann auf der Höhe des vorigen Abschnitts und steigt erneut bis zur Marke.
## recede() lässt es wieder auf `start_level` sinken (Hebel in der Baumkrone).

@export var start_level: float = -0.4
@export var checkpoint_ids: PackedStringArray = PackedStringArray()
@export var stage_levels: PackedFloat32Array = PackedFloat32Array()
@export var stage_speeds: PackedFloat32Array = PackedFloat32Array()   ## m/s je Abschnitt
@export var floating_path: NodePath           ## Knoten mit allem, was schwimmt (y = 0 ist die Oberfläche)
@export var note_id: String = ""              ## Notiz, sobald das Wasser zum ersten Mal steigt
@export var start_message: String = "Das Wasser steigt!"

var water_level := 0.0
var target_level := 0.0
var speed := 0.1
var _stage := -1
var _floating: Array[Node3D] = []
var _base_y := {}   # schwimmender Knoten -> Höhe über der Wasseroberfläche


func _ready() -> void:
	_stage = checkpoint_ids.find(GameState.checkpoint_id)
	water_level = start_level
	target_level = start_level
	if _stage >= 0:
		water_level = start_level if _stage == 0 else stage_levels[_stage - 1]
		_set_stage(_stage)
	var floating := get_node_or_null(floating_path)
	if floating:
		for child in floating.get_children():
			if child is Node3D:
				_floating.append(child)
				_base_y[child] = (child as Node3D).position.y
	_apply()
	GameState.checkpoint_changed.connect(_on_checkpoint_changed)


func _physics_process(delta: float) -> void:
	var before := water_level
	water_level = move_toward(water_level, target_level, speed * delta)
	if water_level != before:
		_apply()


func is_rising() -> bool:
	return water_level < target_level


## Lässt das Wasser mit `recede_speed` auf den Ausgangsstand sinken; es steigt danach nicht mehr.
func recede(recede_speed: float = 1.5) -> void:
	_stage = checkpoint_ids.size()
	target_level = start_level
	speed = recede_speed


## Setzt das Wasser sofort auf den Ausgangsstand (z. B. beim Schnitt in einer Cutscene).
func drain_now() -> void:
	recede()
	water_level = start_level
	_apply()


func _set_stage(index: int) -> void:
	_stage = index
	target_level = stage_levels[index]
	speed = stage_speeds[index] if index < stage_speeds.size() else 0.1


func _apply() -> void:
	position.y = water_level
	for node in _floating:
		if not is_instance_valid(node):
			continue
		if "water_offset" in node:
			node.set("water_offset", water_level - start_level)
		else:
			node.position.y = _base_y[node] + water_level - start_level


func _on_checkpoint_changed(id: String) -> void:
	var index := checkpoint_ids.find(id)
	if index <= _stage:
		return
	var first := _stage < 0
	_set_stage(index)
	if first:
		if note_id != "":
			GameState.unlock_note(note_id)
		if start_message != "":
			GameState.flash_message(start_message, 3.0)
