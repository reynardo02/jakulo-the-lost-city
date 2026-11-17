extends Area3D
## Etwas Lautes am Weg (Level 3): ein trockener, knackender Ast oder flaches Wasser, in dem man
## platscht. Betritt der Spieler den Bereich, hören das alle Schläfer (Gruppe "sleeper",
## sleeping_monkey.gd) in `noise_radius`.
##
## Mit `once` (Ast) knackt es nur einmal: Das Modell unter "Model" bricht ein und bleibt so.
## Ohne `once` (Wasser) platscht es bei jedem Betreten und spritzt ein paar Tropfen hoch.

@export var noise_radius: float = 10.0
@export var once: bool = true
@export var message: String = ""      ## kurze Meldung beim Geräusch ("" = keine)
@export var sound: AudioStream = preload("res://assets/music/sounds/tap.wav")
@export var pitch: float = 0.55

var _done := false
var _player: AudioStreamPlayer3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_player = AudioStreamPlayer3D.new()
	_player.stream = sound
	_player.pitch_scale = pitch
	_player.bus = &"Sounds"
	_player.unit_size = 8.0
	add_child(_player)


func _on_body_entered(body: Node3D) -> void:
	if _done or not body.is_in_group("player"):
		return
	_done = once
	_player.play()
	get_tree().call_group("sleeper", "hear_noise", body.global_position, noise_radius)
	if message != "":
		GameState.flash_message(message, 2.0)
	if once:
		_snap()
	else:
		_splash(body.global_position)


## Der Ast bricht in der Mitte ein.
func _snap() -> void:
	var model := get_node_or_null("Model") as Node3D
	if model == null:
		return
	var tween := create_tween().set_parallel()
	tween.tween_property(model, "position:y", model.position.y - 0.15, 0.12)
	tween.tween_property(model, "rotation:z", model.rotation.z + 0.12, 0.12)


func _splash(at: Vector3) -> void:
	var drops := GPUParticles3D.new()
	drops.amount = 24
	drops.lifetime = 0.7
	drops.one_shot = true
	drops.explosiveness = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.gravity = Vector3(0, -9.8, 0)
	drops.process_material = pm
	var dot := SphereMesh.new()
	dot.radius = 0.04
	dot.height = 0.08
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.8, 0.85, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.material = mat
	drops.draw_pass_1 = dot
	get_tree().current_scene.add_child(drops)
	drops.global_position = at
	drops.emitting = true
	get_tree().create_timer(1.5).timeout.connect(drops.queue_free)
