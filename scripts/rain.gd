extends GPUParticles3D
## Regen (Level 3). Die Tropfen fallen immer in einem Kasten über der aktiven Kamera, deshalb
## reicht ein einziger Emitter fürs ganze Level. Dazu ein prozedurales Rauschen als
## Regengeräusch und ab und zu ein ferner Donner mit kurzem Aufhellen (`flash_light`).
## Die Tropfen selbst (Menge, Material) stellt der Level-Builder ein.

@export var height_above_camera: float = 9.0
@export var ahead_of_camera: float = 6.0
@export var volume_db: float = -10.0
@export var flash_light: NodePath            ## DirectionalLight3D, der beim Blitz kurz aufhellt
@export var thunder_interval: Vector2 = Vector2(14.0, 32.0)   ## Sekunden zwischen zwei Donnern

const MIX_RATE := 22050.0

var _playback: AudioStreamGeneratorPlayback
var _lp_hiss := 0.0
var _lp_hiss2 := 0.0
var _lp_thunder := 0.0
var _thunder := 0.0
var _thunder_delay := -1.0
var _next_flash := 0.0
var _light: DirectionalLight3D
var _light_energy := 1.0


func _ready() -> void:
	emitting = true
	preprocess = 1.0
	_light = get_node_or_null(flash_light) as DirectionalLight3D
	if _light:
		_light_energy = _light.light_energy
	_next_flash = randf_range(thunder_interval.x * 0.5, thunder_interval.y * 0.5)
	_build_audio()


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var forward := -cam.global_basis.z
		forward.y = 0.0
		global_position = cam.global_position + Vector3.UP * height_above_camera \
			+ forward.normalized() * ahead_of_camera
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = randf_range(thunder_interval.x, thunder_interval.y)
		_lightning()
	if _thunder_delay >= 0.0:
		_thunder_delay -= delta
		if _thunder_delay < 0.0:
			_thunder = 1.0
	_fill_audio()


## Kurzes, doppeltes Aufhellen; der Donner folgt etwas später.
func _lightning() -> void:
	_thunder_delay = randf_range(0.6, 1.8)
	if _light == null:
		return
	var tween := create_tween()
	tween.tween_property(_light, "light_energy", _light_energy * 3.5, 0.05)
	tween.tween_property(_light, "light_energy", _light_energy, 0.12)
	tween.tween_property(_light, "light_energy", _light_energy * 2.5, 0.05)
	tween.tween_property(_light, "light_energy", _light_energy, 0.3)


func _build_audio() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.2
	var player := AudioStreamPlayer.new()
	player.stream = gen
	player.bus = &"Sounds"
	player.volume_db = volume_db
	add_child(player)
	player.play()
	_playback = player.get_stream_playback() as AudioStreamGeneratorPlayback


func _fill_audio() -> void:
	if _playback == null:
		return
	for i in _playback.get_frames_available():
		var white := randf() * 2.0 - 1.0
		# Regen: helles Rauschen mit etwas Tiefe
		_lp_hiss += (white - _lp_hiss) * 0.5
		_lp_hiss2 += (white - _lp_hiss2) * 0.08
		var sample := _lp_hiss * 0.3 + _lp_hiss2 * 0.5
		# Donner: tiefes Grollen mit langem Ausklingen
		if _thunder > 0.001:
			_lp_thunder += (white - _lp_thunder) * 0.01
			sample += _lp_thunder * _thunder * 8.0
			_thunder *= 0.99988
		_playback.push_frame(Vector2.ONE * clampf(sample, -1.0, 1.0))
