@tool
extends Node3D
## Runde Teergrube wie in Pitfall Harry.
## Sie ist zuerst offen, schließt sich, bleibt kurz zu und öffnet sich wieder (Endlosschleife).
## Wer bei offener Grube hineinläuft (nicht drüberspringt), versinkt.

signal player_trapped(body: Node3D)

@export var max_radius: float = 2.5:
	set(v):
		max_radius = max(v, 0.1)
		if is_node_ready():
			_apply_radius()
@export var open_time: float = 2.5        ## Sekunden ganz offen
@export var closed_time: float = 2.0      ## Sekunden ganz geschlossen
@export var transition_time: float = 1.2  ## Sekunden für Schließen bzw. Öffnen
@export var start_delay: float = 0.0      ## Versatz, damit mehrere Gruben nicht synchron laufen
@export_range(0.3, 1.0) var kill_margin: float = 0.85  ## tödlicher Anteil des Radius (verzeiht Randberührungen)
@export var sink_depth: float = 2.0
@export var sink_time: float = 1.2
@export var reload_scene_on_trap: bool = true  ## später durch Leben/Respawn ersetzen
@export_range(0.0, 0.5) var closed_hint_size: float = 0.15:  ## so viel Teer bleibt auch geschlossen sichtbar (Anteil vom Radius)
	set(v):
		closed_hint_size = v
		if is_node_ready():
			_apply_radius()

@onready var _visual: Node3D = $Visual
@onready var _mud: Node3D = $MudPatch
@onready var _shape: CollisionShape3D = $Area3D/CollisionShape3D

var _openness := 1.0
var _trapped := false


func _ready() -> void:
	_shape.shape = _shape.shape.duplicate()   # jede Grube bekommt ihre eigene Form
	_apply_radius()
	if Engine.is_editor_hint():
		return
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	_start_cycle()


func _start_cycle() -> void:
	var tw := create_tween().set_loops()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_interval(open_time)
	tw.tween_method(_set_openness, 1.0, 0.0, transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_interval(closed_time)
	tw.tween_method(_set_openness, 0.0, 1.0, transition_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_openness(v: float) -> void:
	_openness = v
	_apply_radius()


func _apply_radius() -> void:
	# Teer schrumpft beim Schließen nur bis auf einen kleinen Fleck in der Mitte
	var s: float = max(max_radius * max(_openness, closed_hint_size), 0.001)
	_visual.scale = Vector3(s, 1.0, s)
	_visual.visible = s > 0.002
	# dunkler Schlammfleck bleibt immer in voller Größe -> Falle ist auch geschlossen erkennbar
	_mud.scale = Vector3(max_radius, 1.0, max_radius)
	(_shape.shape as CylinderShape3D).radius = max_radius


func is_open() -> bool:
	return _openness > 0.05


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or _trapped or not is_open():
		return
	var deadly := max_radius * _openness * kill_margin
	for body in $Area3D.get_overlapping_bodies():
		if not (body is CharacterBody3D and (body.is_in_group("player") or body.name == "Player")):
			continue
		var offset: Vector3 = body.global_position - global_position
		var dist := Vector2(offset.x, offset.z).length()
		# nur fangen, wenn der Spieler am Boden ist (drüberspringen erlaubt)
		if dist < deadly and offset.y < 0.3:
			_trap(body)
			return


func _trap(body: CharacterBody3D) -> void:
	_trapped = true
	player_trapped.emit(body)
	body.set_physics_process(false)
	body.velocity = Vector3.ZERO
	var target := Vector3(global_position.x, global_position.y - sink_depth, global_position.z)
	var tw := create_tween()
	tw.tween_property(body, "global_position", target, sink_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if reload_scene_on_trap:
		tw.tween_callback(get_tree().reload_current_scene)
