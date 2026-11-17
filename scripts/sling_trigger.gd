extends Node3D
## Ziel der Schlinge, das etwas anderes auslöst (Level 3): ein Seil, das eine Plattform hält,
## oder eine Zielscheibe, die einen Ast als Brücke umklappt. Beim Treffer wird activate() an
## allen Knoten in `targets` gerufen (z. B. moving_part.gd).
##
## style "rope":  das Modell (Model) verschwindet, das Seil ist durchtrennt.
## style "board": die Scheibe (Model) klappt nach hinten weg.

@export var targets: Array[NodePath] = []
@export_enum("rope", "board") var style: String = "board"
@export var message: String = ""
@export var hit_radius: float = 1.0   ## so weit darf der Schuss danebengehen (m)

@onready var _model: Node3D = $Model

var _hit := false


func _ready() -> void:
	add_to_group("sling_target")


func can_be_hit() -> bool:
	return not _hit


func get_sling_point() -> Vector3:
	return global_position


func get_sling_radius() -> float:
	return hit_radius


func sling_hit() -> void:
	if _hit:
		return
	_hit = true
	remove_from_group("sling_target")
	if style == "rope":
		_model.hide()
	else:
		var tween := create_tween()
		tween.tween_property(_model, "rotation:x", _model.rotation.x - deg_to_rad(80.0), 0.35) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for path in targets:
		var node := get_node_or_null(path)
		if node and node.has_method("activate"):
			node.activate()
	if message != "":
		GameState.flash_message(message, 2.0)
