extends Node3D
## Krokodil als Trittstein wie in Pitfall.
## Es liegt mit geschlossenem Maul im Wasser. Erst wenn der Spieler es berührt, zuckt es
## kurz (Reaktionszeit) und reißt dann das Maul auf. Ist der Spieler noch darauf, wird er
## gepackt, sonst schnappt es ins Leere. Beim Packen bäumt sich das Krokodil
## senkrecht auf, der Spieler steckt zwischen den Kiefern und hält sie mit je einer Hand
## am Ober- und am Unterkiefer auseinander. Jedes Drücken von "jump" stemmt das Maul ein
## Stück weiter auf; beim letzten Stoß springt er heraus. Schafft er es nicht rechtzeitig,
## schnappt das Maul zu, das Krokodil taucht mit ihm ab und er verliert ein Leben.
##
## Animation: Hat das Modell unter "Model" einen AnimationPlayer mit der Animation
## `bite_animation` (zu -> offen), wird sie beim Öffnen vorwärts und beim Schließen
## rückwärts abgespielt. Ohne diese Animation hebt das ganze Modell den Kopf.
##
## Für Ketten aus mehreren Krokodilen (Level 2): Mit `snap_interval` > 0 schnappt das
## Krokodil zusätzlich von selbst in festem Takt, `snap_offset` verschiebt den Takt, damit
## mehrere Krokodile nacheinander schnappen. Schneller wird es über `warning_time`,
## `open_time` und `snap_interval`.

signal mouth_opened
signal mouth_closed

enum State { CLOSED, WARNING, OPEN, GRABBED, ESCAPING, SWALLOWED, RESTING }

@export var warning_time: float = 0.8   ## Reaktionszeit nach der Berührung, bevor das Maul aufgeht (0 = sofort)
@export var open_time: float = 0.6      ## so lange bleibt das Maul offen, wenn der Spieler schon weg ist
@export var rearm_delay: float = 1.5    ## nach dem Befreien: so lange ohne Spieler, bis es wieder zuschnappt
@export var bite_animation: StringName = &"bite"  ## Animation des geriggten Modells
@export var note_id: String = "crocodile"  ## Notiz im Buch, die bei der ersten Berührung freigeschaltet wird

@export_group("Schnappen im Takt")
@export var snap_interval: float = 0.0  ## alle so viele Sekunden schnappt es von selbst (0 = nur bei Berührung)
@export var snap_offset: float = 0.0    ## Zeitversatz des Takts, z. B. 0 / 0.5 / 1.0 für drei Krokodile hintereinander
@export var trigger_on_touch: bool = true  ## aus = reagiert nicht auf Berührung, schnappt nur im Takt

@export_group("Packen und Befreien")
@export var struggle_time: float = 2.5    ## so lange hat der Spieler Zeit, sich zu befreien
@export var presses_to_escape: int = 6    ## so oft muss "jump" gedrückt werden
@export var escape_jump_velocity: float = 6.5  ## Sprung aus dem Maul nach oben
@export var escape_hint: String = "SPRINGEN drücken, um dich zu befreien!"
@export var rear_up_time: float = 0.45    ## so lange dauert das Aufbäumen zum Spieler
@export var rear_down_time: float = 0.5   ## Zurücklegen nach dem Befreien
@export var thrash_degrees: float = 10.0  ## Hin- und Herdrehen mit dem Spieler im Maul
@export var rear_lean_degrees: float = 0.0   ## Neigung aus der Senkrechten
@export var escape_open_degrees: float = 24.0  ## so weit stemmt der Spieler das Maul bis zur Befreiung zusätzlich auf
@export var upper_jaw_bone: StringName = &"Head"  ## Knochen, an dem der Oberkiefer (UpperJawTip) hängt
@export var lower_jaw_bone: StringName = &"Jaw"   ## Knochen des Unterkiefers (LowerJawTip)
@export var swallow_sink: float = 1.6     ## so weit taucht das Krokodil beim Verschlingen ab

@export_group("Signale ohne Rig-Animation")
@export var tilt_degrees: float = 10.0  ## so weit hebt sich der Kopf (Kopf liegt bei +Z des Modells)
@export var shake_degrees: float = 2.0  ## Zucken während der Vorwarnung

@onready var _model: Node3D = $Model
@onready var _bite_area: Area3D = $BiteArea
@onready var _upper_tip: Marker3D = $UpperJawTip  # dort greift eine Hand des Spielers ...
@onready var _lower_tip: Marker3D = $LowerJawTip  # ... und dort die andere
@onready var _back_point: Marker3D = $BackPoint     # Landepunkt nach dem Befreien

var _anim_player: AnimationPlayer
var _state := State.CLOSED
var _time_left := 0.0
var _rest: Transform3D
var _victim: Node3D
var _presses := 0
var _snap_left := 0.0   # Zeit bis zum nächsten Schnappen im Takt

# Aufbäumen: 0 = liegt normal, 1 = steht senkrecht mit dem Maul am Spieler
var _rear_amount := 0.0
var _rear_active := false
var _grab_point := Vector3.ZERO   # Mitte zwischen den Händen beim Packen, lokal zum Krokodil
var _sink := 0.0
var _rear_tween: Tween

# Maul weiter aufstemmen (über die Bite-Animation hinaus)
var _skeleton: Skeleton3D
var _upper_bone := -1
var _lower_bone := -1
var _upper_open: Quaternion   # Knochenrotation am Ende der Bite-Animation
var _lower_open: Quaternion
var _jaw_base_saved := false
var _extra_open := 0.0          # zusätzliche Öffnung in Radiant


func _ready() -> void:
	_rest = _model.transform
	_anim_player = _find_bite_player()
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0]
		_upper_bone = _skeleton.find_bone(upper_jaw_bone)
		_lower_bone = _skeleton.find_bone(lower_jaw_bone)
	_attach_to_bone(_upper_tip, _upper_bone)
	_attach_to_bone(_lower_tip, _lower_bone)
	_bite_area.body_entered.connect(_on_bite_area_body_entered)
	_snap_left = snap_interval + maxf(snap_offset, 0.0)


func is_open() -> bool:
	return _state == State.OPEN


## Hängt einen Marker an einen Knochen, damit er dem Kiefer in jeder Animation folgt.
func _attach_to_bone(marker: Marker3D, bone: int) -> void:
	if bone < 0:
		marker.reparent(_model)
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_idx = bone
	_skeleton.add_child(attachment)
	# sofort auf den Knochen setzen, sonst rechnet reparent() gegen eine noch leere Transform
	attachment.global_transform = _skeleton.global_transform * _skeleton.get_bone_global_pose(bone)
	marker.reparent(attachment)


func _find_bite_player() -> AnimationPlayer:
	for p in _model.find_children("*", "AnimationPlayer", true, false):
		if (p as AnimationPlayer).has_animation(bite_animation):
			return p
	return null


func _physics_process(delta: float) -> void:
	_time_left -= delta
	# Der Takt läuft immer weiter, damit der Versatz in einer Kette auch nach einem
	# Biss erhalten bleibt. Fällt ein Schlag in eine andere Phase, verfällt er.
	var snap_due := false
	if snap_interval > 0.0:
		_snap_left -= delta
		if _snap_left <= 0.0:
			_snap_left += snap_interval
			snap_due = true
	if _rear_active:
		_apply_rear()
	if _state == State.GRABBED:
		_apply_extra_open()
		_process_grab()
		return
	if _state == State.ESCAPING:
		_apply_extra_open()
		_hold_victim()
		return
	if _state == State.SWALLOWED:
		_hold_victim()
		return
	if _state == State.CLOSED:
		var touched := _player_on_top()
		if touched:
			GameState.unlock_note(note_id)
		if snap_due or (trigger_on_touch and touched):
			_state = State.WARNING
			_time_left = warning_time
		return
	if _state == State.RESTING:
		# nach dem Befreien erst wieder scharf, wenn der Spieler eine Weile weg ist
		if _player_on_top():
			_time_left = rearm_delay
		elif _time_left <= 0.0:
			_state = State.CLOSED
		return
	if _state == State.WARNING and not _rear_active:
		# Zucken um die Längsachse
		var phase := (warning_time - _time_left) / maxf(warning_time, 0.01)
		_model.rotation.z = _rest.basis.get_euler().z + deg_to_rad(shake_degrees) * sin(phase * TAU * 3.0)
	if _time_left > 0.0:
		return
	match _state:
		State.WARNING:
			_open()
		State.OPEN:
			_close()


func _player_on_top() -> bool:
	for body in _bite_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false


func _open() -> void:
	_state = State.OPEN
	_time_left = open_time
	if not _rear_active:
		_model.transform = _rest
	mouth_opened.emit()
	if _anim_player:
		_anim_player.play(bite_animation)
	elif not _rear_active:
		_tilt_to(-deg_to_rad(tilt_degrees), 0.15)
	for body in _bite_area.get_overlapping_bodies():
		_bite(body)


func _close() -> void:
	_state = State.CLOSED
	mouth_closed.emit()
	if _anim_player:
		_anim_player.play_backwards(bite_animation)
	elif not _rear_active:
		_tilt_to(0.0, 0.3)


func _tilt_to(angle: float, duration: float) -> void:
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(_model, "rotation:x", _rest.basis.get_euler().x + angle, duration)


func _on_bite_area_body_entered(body: Node3D) -> void:
	if _state == State.OPEN:
		_bite(body)


func _bite(body: Node3D) -> void:
	if _state != State.OPEN or not body.is_in_group("player"):
		return
	_victim = body
	GameState.unlock_note(note_id)
	_presses = 0
	_extra_open = 0.0
	_jaw_base_saved = false
	_state = State.GRABBED
	_time_left = struggle_time
	# Der Spieler bleibt, wo er ist - das Krokodil kommt zu ihm.
	if _victim.has_method("capture"):
		_victim.capture()
	else:
		_victim.set_physics_process(false)
	var grip: Vector3 = _victim.get_grip_point() if _victim.has_method("get_grip_point") \
		else _victim.global_position
	_grab_point = to_local(grip)
	_sink = 0.0
	_rear_active = true
	_tween_rear(1.0, rear_up_time, Tween.EASE_OUT)
	GameState.show_message(escape_hint)


# ---------- Aufbäumen ----------

## Setzt das Modell zwischen Ruhelage und "senkrecht, Maul am Spieler".
func _apply_rear() -> void:
	# Kopf (+Z des Modells) zeigt nach oben, dazu Drehen um die Hochachse (Schütteln).
	# Die Mitte zwischen den Kieferspitzen bleibt an den Händen des Spielers - auch
	# während sich das Maul weiter öffnet.
	var thrash := 0.0
	if _state == State.GRABBED or _state == State.ESCAPING:
		thrash = deg_to_rad(thrash_degrees) * sin(_time_left * TAU * 2.5) * _rear_amount
	var upright := Basis(Vector3.UP, thrash) * Basis(Vector3.RIGHT, -PI / 2.0 + deg_to_rad(rear_lean_degrees))
	var mouth_mid := _model.to_local((_upper_tip.global_position + _lower_tip.global_position) * 0.5)
	var origin := _grab_point - upright * mouth_mid + Vector3.DOWN * _sink
	var reared := Transform3D(upright, origin)
	_model.transform = _rest.interpolate_with(reared, _rear_amount)
	if _rear_amount <= 0.0 and _state in [State.CLOSED, State.WARNING, State.OPEN, State.RESTING]:
		_rear_active = false
		_model.transform = _rest


func _tween_rear(target: float, duration: float, ease_type: Tween.EaseType) -> void:
	if _rear_tween:
		_rear_tween.kill()
	_rear_tween = create_tween()
	_rear_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_rear_tween.tween_property(self, "_rear_amount", target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)


# ---------- Packen und Befreien ----------

func _process_grab() -> void:
	if not is_instance_valid(_victim):
		_tween_rear(0.0, rear_down_time, Tween.EASE_IN_OUT)
		_close()
		return
	_hold_victim()
	if Input.is_action_just_pressed("jump"):
		_presses += 1
		if _victim.has_method("struggle"):
			_victim.struggle()
		var tw := create_tween()
		tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tw.tween_property(self, "_extra_open", deg_to_rad(escape_open_degrees) * _presses / presses_to_escape, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if _presses >= presses_to_escape:
			# letzter Stoß: Maul ganz aufdrücken, dann rausspringen
			_state = State.ESCAPING
			tw.tween_callback(_release_victim)
			return
		GameState.show_message("%s (%d/%d)" % [escape_hint, _presses, presses_to_escape])
	if _time_left <= 0.0:
		_swallow()


## Drückt Ober- und Unterkiefer über das Ende der Bite-Animation hinaus auseinander.
func _apply_extra_open() -> void:
	if _upper_bone < 0 or _lower_bone < 0 or (_anim_player and _anim_player.is_playing()):
		return
	if not _jaw_base_saved:
		_upper_open = _skeleton.get_bone_pose_rotation(_upper_bone)
		_lower_open = _skeleton.get_bone_pose_rotation(_lower_bone)
		_jaw_base_saved = true
	# Unterkiefer öffnet um +X, Oberkiefer hebt sich um -X (wie in der Bite-Animation)
	_skeleton.set_bone_pose_rotation(_lower_bone, _lower_open * Quaternion(Vector3.RIGHT, _extra_open * 0.6))
	_skeleton.set_bone_pose_rotation(_upper_bone, _upper_open * Quaternion(Vector3.RIGHT, -_extra_open * 0.4))


## Je eine Hand des Spielers an Ober- und Unterkiefer. Während des Aufbäumens gleiten die
## Griffpunkte von den Händen beim Packen zu den echten Kieferspitzen.
func _hold_victim() -> void:
	if not is_instance_valid(_victim) or not _victim.has_method("brace_between"):
		return
	var mid := to_global(_grab_point)
	# aufgebäumt liegt der Oberkiefer auf der -Z-Seite des Krokodils, der Unterkiefer auf +Z
	var spread := global_basis.z.normalized() * 0.45
	var upper := (mid - spread).lerp(_upper_tip.global_position, _rear_amount)
	var lower := (mid + spread).lerp(_lower_tip.global_position, _rear_amount)
	# Blick quer zum Maul, damit die Arme zu beiden Kiefern zeigen
	_victim.brace_between(upper, lower, _model.global_basis.x)


func _release_victim() -> void:
	GameState.show_message("")
	if not is_instance_valid(_victim):
		return
	# Sprung aus dem Maul zurück auf den Rücken, das Krokodil legt sich wieder hin
	var to_back := _back_point.global_position - _victim.global_position
	to_back.y = 0.0
	var air_time := 2.0 * escape_jump_velocity / 9.8
	var launch := to_back / air_time + Vector3.UP * escape_jump_velocity
	if _victim.has_method("escape"):
		_victim.escape(launch)
	else:
		_victim.set_physics_process(true)
	_victim = null
	_tween_rear(0.0, rear_down_time, Tween.EASE_IN_OUT)
	_close()
	# der Spieler landet auf dem Rücken - nicht gleich wieder zuschnappen
	_state = State.RESTING
	_time_left = rearm_delay


func _swallow() -> void:
	_state = State.SWALLOWED
	GameState.show_message("")
	mouth_closed.emit()
	if _anim_player:
		_anim_player.play_backwards(bite_animation)   # Maul schnappt zu
	# senkrecht abtauchen, der Spieler wird am Kiefer mit hinabgezogen
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "_sink", swallow_sink, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_callback(_victim.hide).set_delay(0.6)
	GameState.player_died(_victim, 1.0)
