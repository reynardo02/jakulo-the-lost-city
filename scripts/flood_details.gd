extends Node3D
## Tied to the actual gate and water state, including checkpoint reloads and skips.
var _water: Node3D
var _inlet: Node3D
var _sound: AudioStreamPlayer3D
var _spray: GPUParticles3D
var _wet: ShaderMaterial
var _high_water := -0.4

func _ready() -> void:
	var level := get_parent()
	_water = level.get_node("Wasser")
	_inlet = level.get_node("Lichtung/SchleusenWasser")
	_sound = AudioStreamPlayer3D.new()
	var flow := preload("res://assets/music/sounds/water_flow.wav").duplicate() as AudioStreamWAV
	flow.loop_mode = AudioStreamWAV.LOOP_FORWARD
	flow.loop_end = flow.data.size() / 2
	_sound.stream = flow
	_sound.bus = &"Sounds"
	_sound.unit_size = 12.0
	_sound.max_distance = 70.0
	_sound.volume_db = -10.0
	add_child(_sound)
	_sound.global_position = _inlet.global_position
	_spray = GPUParticles3D.new()
	_spray.amount = 48
	_spray.lifetime = 1.5
	_spray.visibility_aabb = AABB(Vector3(-12,-4,-8),Vector3(24,16,16))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(-1, 0.15, 0)
	process.spread = 14.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 4.0
	process.gravity = Vector3(0,-2.0,0)
	process.scale_min = 0.035
	process.scale_max = 0.09
	_spray.process_material = process
	var mesh := SphereMesh.new()
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65,0.76,0.7)
	mat.roughness = 0.35
	mesh.material = mat
	_spray.draw_pass_1 = mesh
	add_child(_spray)
	_wet = ShaderMaterial.new()
	_wet.shader = preload("res://assets/terrain/wet_overlay.gdshader")
	for mi in level.get_node("Teil2_Baum/Stamm").find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = _wet

func _process(_delta: float) -> void:
	var flowing := _inlet.is_visible_in_tree()
	_spray.emitting = flowing
	_spray.global_position = Vector3(_inlet.global_position.x, _water.global_position.y + 0.2, _inlet.global_position.z)
	if flowing and not _sound.playing:
		_sound.play()
	elif not flowing and _sound.playing:
		_sound.stop()
	_high_water = maxf(_high_water, _water.global_position.y)
	_wet.set_shader_parameter("wet_level", _high_water)
