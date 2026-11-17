extends Node3D
## Short local work routine, deliberately separate from guard perception.
@export var work_offset := Vector3(0,0,2)
@export var speed := 0.65
var _origin := Vector3.ZERO
var _going_out := true
var _wait := 3.0
var _anim: AnimationPlayer

func _ready() -> void:
	_origin = position
	for child in find_children("*", "AnimationPlayer", true, false):
		_anim = child
		break
	for clip in ["Idle", "Walk"]:
		if _anim and _anim.has_animation(clip):
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

func _process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		_play("Idle")
		return
	var target := _origin + work_offset if _going_out else _origin
	var offset := target-position
	if offset.length() < 0.05:
		_going_out = not _going_out
		_wait = 5.0 if _going_out else 8.0
		return
	rotation.y = rotate_toward(rotation.y, atan2(offset.x,offset.z), delta*2.0)
	position += offset.normalized()*minf(speed*delta, offset.length())
	_play("Walk")

func _play(clip: String) -> void:
	if _anim and _anim.has_animation(clip) and _anim.current_animation != clip:
		_anim.play(clip,0.3)
