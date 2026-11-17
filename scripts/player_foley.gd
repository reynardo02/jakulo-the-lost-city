extends Node
## Distance-based steps; the same impulses drive sound and AI hearing.

const SOUNDS := {
	"earth": preload("res://assets/music/sounds/step_earth.wav"),
	"wood": preload("res://assets/music/sounds/step_wood.wav"),
	"stone": preload("res://assets/music/sounds/step_stone.wav"),
	"water": preload("res://assets/music/sounds/step_water.wav"),
}
const STEP_DB := -20.0   ## Grundpegel eines Schritts
const LAND_DB := -15.0   ## Grundpegel einer Landung
const SURFACE_DB := {"water": -3.0, "wood": -1.0}   ## nasse Schritte rauschen breiter, daher leiser

var _distance := 0.0
var _sound: AudioStreamPlayer3D
var _player: CharacterBody3D
var _noise_until := 0
var _loudness := 0.0
var _clips := {}
var _last_variant := -1

func _ready() -> void:
	for surface in SOUNDS:
		for prefix in ["step_", "land_"]:
			var variants: Array[AudioStream] = []
			for i in 3:
				var suffix := "" if i == 0 else "_%d" % (i + 1)
				variants.append(load("res://assets/music/sounds/%s%s%s.wav" % [prefix, surface, suffix]))
			_clips[prefix + surface] = variants
	_player = get_parent() as CharacterBody3D
	_sound = AudioStreamPlayer3D.new()
	_sound.bus = &"Sounds"
	_sound.max_distance = 24.0
	_sound.unit_size = 6.0
	_sound.max_polyphony = 3
	_player.add_child.call_deferred(_sound)

func loudness() -> float:
	return _loudness if Time.get_ticks_msec() < _noise_until else 0.0

func update_motion(delta: float, was_grounded: bool, impact: float) -> void:
	if not _sound.is_inside_tree():
		return
	if not _player.is_on_floor():
		_distance = 0.0
		return
	if not was_grounded and impact > 1.8:
		_step(clampf(impact / 5.0, 0.7, 1.8), true)
		_distance = 0.0
		return
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if speed < 0.25:
		_distance = 0.0
		return
	_distance += speed * delta
	var sneaking: bool = _player.get("is_sneaking") == true
	if _distance >= (1.1 if sneaking else 1.8):
		_distance = 0.0
		_step(0.12 if sneaking else clampf(speed / 5.0, 0.2, 1.0), false)

func _surface() -> String:
	for i in _player.get_slide_collision_count():
		var hit := _player.get_slide_collision(i)
		if hit.get_normal().dot(Vector3.UP) < 0.55:
			continue
		var node := hit.get_collider() as Node
		while node and node != get_tree().current_scene:
			if node.has_meta("footstep_surface"):
				return str(node.get_meta("footstep_surface"))
			var label := str(node.name).to_lower()
			if "seerose" in label or "lily" in label or "croc" in label or "krokodil" in label or "wasser" in label:
				return "water"
			if "platform" in label or "plattform" in label or "steg" in label or "bruecke" in label or "log" in label or "stamm" in label:
				return "wood"
			if "stone" in label or "stein" in label or "ruin" in label or "temple" in label:
				return "stone"
			node = node.get_parent()
	return "earth"

func _step(strength: float, landing: bool) -> void:
	var surface := _surface()
	if not SOUNDS.has(surface):
		surface = "earth"
	var variant := randi_range(0, 2)
	if variant == _last_variant:
		variant = (variant + 1 + randi_range(0, 1)) % 3
	_last_variant = variant
	_sound.stream = _clips[("land_" if landing else "step_") + surface][variant]
	# Leise und unaufdringlich: Schritte liegen deutlich unter Musik und Ambiente.
	# Kleine Schwankungen in Tonhöhe und Pegel verhindern das "Maschinengewehr" gleicher Schritte.
	_sound.pitch_scale = randf_range(0.94, 1.06)
	var base := LAND_DB if landing else STEP_DB
	base += SURFACE_DB.get(surface, 0.0)
	_sound.volume_db = base + linear_to_db(clampf(strength, 0.3, 1.1)) + randf_range(-1.5, 1.5)
	_sound.play()
	_loudness = strength * (1.3 if surface == "water" or surface == "wood" else 1.0)
	_noise_until = Time.get_ticks_msec() + 430
	get_tree().call_group("guards", "hear_noise", _player.global_position, 5.0 * _loudness)
	if landing:
		get_tree().call_group("sleeper", "hear_noise", _player.global_position, 4.0 * _loudness)
