extends AnimatableBody3D
## Bewegliches Bauteil, das auf ein Signal hin einmal an seine Endstellung fährt (Level 3):
## eine Plattform, die herunterfällt, sobald ihr Seil durchtrennt ist, oder ein Ast, der als
## Brücke umklappt. Ausgelöst wird es über activate(), z. B. von sling_trigger.gd.
##
## Die Endstellung ist relativ zur Startstellung: Verschiebung `end_offset` (im Elternraum)
## und zusätzliche Drehung `end_rotation_deg` (Eulerwinkel, wie `rotation`).

@export var end_offset: Vector3 = Vector3.ZERO
@export var end_rotation_deg: Vector3 = Vector3.ZERO
@export var duration: float = 0.9
@export var bounce: bool = true

var _done := false


func activate() -> void:
	if _done:
		return
	_done = true
	# im Physik-Takt, damit der Körper sauber mitbewegt wird; nur animieren, was sich ändert
	var tween := create_tween().set_parallel().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var trans := Tween.TRANS_BOUNCE if bounce else Tween.TRANS_QUAD
	if end_offset != Vector3.ZERO:
		tween.tween_property(self, "position", position + end_offset, duration) \
			.set_trans(trans).set_ease(Tween.EASE_OUT)
	if end_rotation_deg != Vector3.ZERO:
		tween.tween_property(self, "rotation", rotation + end_rotation_deg * (PI / 180.0), duration) \
			.set_trans(trans).set_ease(Tween.EASE_OUT)
