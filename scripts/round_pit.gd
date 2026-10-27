@tool
extends Node3D
## Runde Grube wie in Pitfall.
## Ein 12 x 12 m Bodenblock mit echtem Loch. Eine grüne Abdeckung zieht sich wie eine
## Blende zusammen (Grube offen) und schließt sich wieder (Grube zu). Endlosschleife.
## Wer bei offener Grube hineinfällt, landet in der Todeszone am Grubenboden.

signal player_trapped(body: Node3D)

const COVER_RADIUS := 4.6   # passt zum Loch in assets/traps/pit_tile.glb (Radius 4.5)

@export var open_time: float = 2.5        ## Sekunden ganz offen
@export var closed_time: float = 2.0      ## Sekunden ganz geschlossen
@export var transition_time: float = 1.2  ## Sekunden für Öffnen bzw. Schließen
@export var start_delay: float = 0.0      ## Versatz, damit mehrere Gruben nicht synchron laufen
@export var reload_scene_on_trap: bool = true  ## später durch Leben/Respawn ersetzen
@export var reload_delay: float = 0.8
@export var editor_preview_open: bool = false:  ## nur Editor: Grube offen anzeigen
	set(v):
		editor_preview_open = v
		if is_node_ready() and Engine.is_editor_hint():
			_set_openness(1.0 if v else 0.0)

@onready var _cover_mesh: MeshInstance3D = $Cover/CoverMesh
@onready var _cover_shape: CollisionShape3D = $Cover/CoverShape
@onready var _death_zone: Area3D = $DeathZone

var _openness := 1.0
var _trapped := false


func _ready() -> void:
	_cover_shape.shape = _cover_shape.shape.duplicate()   # jede Grube eigene Form
	_use_grass_material()
	if Engine.is_editor_hint():
		_set_openness(1.0 if editor_preview_open else 0.0)
		return
	_death_zone.body_entered.connect(_on_death_zone_body_entered)
	_set_openness(1.0)   # startet offen
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	_start_cycle()


## Abdeckung bekommt exakt das Gras-Material des Bodenblocks -> geschlossen kaum vom Boden zu unterscheiden
func _use_grass_material() -> void:
	for mi in $PitTile.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var m := mesh.surface_get_material(i)
			if m and m.resource_name == "grass":
				_cover_mesh.material_override = m
				return


func _start_cycle() -> void:
	var tw := create_tween().set_loops()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_interval(open_time)
	tw.tween_method(_set_openness, 1.0, 0.0, transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(closed_time)
	tw.tween_method(_set_openness, 0.0, 1.0, transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_openness(v: float) -> void:
	_openness = v
	var c: float = 1.0 - v   # wie weit die Abdeckung geschlossen ist
	_cover_mesh.scale = Vector3(max(c, 0.001), 1.0, max(c, 0.001))
	_cover_mesh.visible = c > 0.01
	(_cover_shape.shape as CylinderShape3D).radius = max(COVER_RADIUS * c, 0.01)
	_cover_shape.disabled = c < 0.03


func is_open() -> bool:
	return _openness > 0.05


func _on_death_zone_body_entered(body: Node3D) -> void:
	if _trapped or not (body is CharacterBody3D and (body.is_in_group("player") or body.name == "Player")):
		return
	_trapped = true
	player_trapped.emit(body)
	body.set_physics_process(false)
	(body as CharacterBody3D).velocity = Vector3.ZERO
	if reload_scene_on_trap:
		await get_tree().create_timer(reload_delay).timeout
		get_tree().reload_current_scene()
