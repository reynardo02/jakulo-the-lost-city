extends Node3D
## Sparse positional calls, never a continuous competing music track.
@export var quiet: bool = false
var _wait := 3.0
var _call: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_call = AudioStreamPlayer3D.new()
	_call.stream = preload("res://assets/music/sounds/jungle_call.wav")
	_call.bus = &"Sounds"
	_call.volume_db = -12.0 if quiet else -8.0
	_call.max_distance = 45.0
	_call.unit_size = 8.0
	add_child(_call)

func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = _rng.randf_range(8.0, 18.0)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player or not player.is_physics_processing():
		return
	var angle := _rng.randf_range(0.0, TAU)
	_call.global_position = player.global_position + Vector3(cos(angle) * 15.0, 7.0, sin(angle) * 15.0)
	_call.pitch_scale = _rng.randf_range(0.75, 1.3)
	_call.play()
