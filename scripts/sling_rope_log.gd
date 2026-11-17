extends Node3D
## Baumstamm, der aufrecht steht und von einem Seil gehalten wird (Ziel der Schlinge).
## Ein Treffer durchtrennt das Seil: Der Stamm kippt um den Ursprung dieses Knotens nach -Z
## und liegt danach als Brücke über der Lücke.
##
## Aufbau: Pivot (Node3D, Drehpunkt am Boden) -> Log (AnimatableBody3D, Stamm entlang +Y),
## Rope (MeshInstance3D, wird hier zwischen Stammspitze und Anchor gespannt), Anchor (Marker3D).

@export var fall_time: float = 1.1
@export var fallen_angle_deg: float = -90.0   ## Drehung um X, wenn der Stamm liegt
@export var hint: String = "Das Seil hält den Stamm. Mit der Schlinge durchtrennen?"

@onready var _pivot: Node3D = $Pivot
@onready var _rope: MeshInstance3D = $Rope
@onready var _anchor: Marker3D = $Anchor
@onready var _rope_top: Marker3D = $Pivot/RopeTop

var _cut := false


func _ready() -> void:
	add_to_group("sling_target")
	_stretch_rope()


func can_be_hit() -> bool:
	return not _cut


func get_sling_point() -> Vector3:
	return _rope.global_position


func get_sling_radius() -> float:
	return 1.1


func sling_hit() -> void:
	if _cut:
		return
	_cut = true
	remove_from_group("sling_target")
	_rope.visible = false
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:x", deg_to_rad(fallen_angle_deg), fall_time) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Spannt das Seil als dünnen Zylinder zwischen Stammspitze und Anker.
func _stretch_rope() -> void:
	var a := _rope_top.position
	var b := _anchor.position
	var length := a.distance_to(b)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.05
	mesh.height = length
	mesh.radial_segments = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.5, 0.32)
	mesh.material = mat
	_rope.mesh = mesh
	_rope.position = (a + b) * 0.5
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD)
	if side.length_squared() < 0.001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	_rope.basis = Basis(side, up, side.cross(up))
