extends Node3D
## Wespennest im Baum (Ziel der Schlinge). Getroffen fällt es herunter, die Wespen schwärmen
## aus und vertreiben das Tier unter `scares` (scared_animal.gd).

@export var scares: NodePath
@export var fall_distance: float = 4.0
@export var message: String = "Die Wespen jagen den Affen davon!"

@onready var _model: Node3D = $Model

var _hit := false


func _ready() -> void:
	add_to_group("sling_target")


func can_be_hit() -> bool:
	return not _hit


func get_sling_point() -> Vector3:
	return _model.global_position + Vector3.UP * 0.8   # Mitte des Nests


func get_sling_radius() -> float:
	return 1.2


func sling_hit() -> void:
	if _hit:
		return
	_hit = true
	remove_from_group("sling_target")
	var tween := create_tween()
	tween.tween_property(_model, "position:y", _model.position.y - fall_distance, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_release_wasps)


func _release_wasps() -> void:
	_spawn_swarm()
	var animal := get_node_or_null(scares)
	if animal and animal.has_method("flee"):
		animal.flee()
	if message != "":
		GameState.flash_message(message, 2.5)


## Ein paar schwarze Punkte, die kurz um das Nest schwirren
func _spawn_swarm() -> void:
	var swarm := GPUParticles3D.new()
	swarm.amount = 40
	swarm.lifetime = 1.6
	swarm.one_shot = true
	swarm.explosiveness = 0.6
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3.ZERO
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	swarm.process_material = pm
	var dot := SphereMesh.new()
	dot.radius = 0.04
	dot.height = 0.08
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.04)
	dot.material = mat
	swarm.draw_pass_1 = dot
	add_child(swarm)
	swarm.global_position = _model.global_position + Vector3.UP * 0.6
	swarm.emitting = true
	# die Wespen jagen den Affen hinterher und sind dann weg
	var chase := create_tween()
	chase.tween_property(swarm, "global_position", swarm.global_position + Vector3(0, 6, 4), 2.0) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	chase.tween_callback(swarm.queue_free)
	# das zerbrochene Nest löst sich auf, statt auf dem Ast liegen zu bleiben
	var crumble := create_tween()
	crumble.tween_interval(0.8)
	crumble.tween_property(_model, "scale", _model.scale * 0.05, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	crumble.tween_callback(_model.hide)
