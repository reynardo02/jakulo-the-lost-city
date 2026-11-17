extends MeshInstance3D
var _age := 0.0
var _material: StandardMaterial3D

func _ready() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.43
	ring.outer_radius = 0.47
	ring.rings = 24
	ring.ring_segments = 6
	mesh = ring
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(0.65, 0.78, 0.72, 0.4)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	_age += delta
	scale = Vector3(1.0 + _age * 2.0, 0.15, 1.0 + _age * 2.0)
	_material.albedo_color.a = maxf(0.0, 0.4 * (1.0 - _age / 1.2))
	if _age >= 1.2:
		queue_free()
