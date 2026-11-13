extends Node3D
## Krokodil als Trittstein wie in Pitfall.
## Zyklus: Maul zu (sicher) -> Warnung (zuckt) -> Maul offen -> wieder zu.
## Wer bei offenem Maul auf dem Krokodil steht, wird gepackt: Das Krokodil dreht sich
## senkrecht nach oben und schnappt von unten zu, der Spieler bleibt dabei an seinem Platz.
## Durch wiederholtes Drücken von "jump" kann er sich befreien; schafft er es nicht
## rechtzeitig, wird er verschlungen und verliert ein Leben.
##
## Animation: Hat das Modell unter "Model" einen AnimationPlayer mit der Animation
## `bite_animation` (zu -> offen), wird sie beim Öffnen vorwärts und beim Schließen
## rückwärts abgespielt. Ohne diese Animation hebt das ganze Modell den Kopf.

signal mouth_opened
signal mouth_closed

enum State { CLOSED, WARNING, OPEN, GRABBED, SWALLOWED }

@export var closed_time: float = 2.5    ## Sekunden Maul zu (sicher)
@export var warning_time: float = 0.6   ## Sekunden Vorwarnung vor dem Öffnen
@export var open_time: float = 1.5      ## Sekunden Maul offen (packt den Spieler)
@export var start_delay: float = 0.0    ## Versatz, damit mehrere Krokodile nicht synchron laufen
@export var bite_animation: StringName = &"bite"  ## Animation des geriggten Modells

@export_group("Packen und Befreien")
@export var struggle_time: float = 2.5    ## so lange hat der Spieler Zeit, sich zu befreien
@export var presses_to_escape: int = 6    ## so oft muss "jump" gedrückt werden
@export var escape_jump_velocity: float = 6.5  ## Sprung aus dem Maul nach oben
@export var escape_hint: String = "SPRINGEN drücken, um dich zu befreien!"
@export var rear_up_time: float = 0.45    ## so lange dauert das Aufbäumen zum Spieler
@export var rear_down_time: float = 0.5   ## Zurücklegen nach dem Befreien
@export var thrash_degrees: float = 10.0  ## Hin- und Herdrehen mit dem Spieler im Maul
@export var swallow_sink: float = 1.6     ## so weit taucht das Krokodil beim Verschlingen ab

@export_group("Signale ohne Rig-Animation")
@export var tilt_degrees: float = 10.0  ## so weit hebt sich der Kopf (Kopf liegt bei +Z des Modells)
@export var shake_degrees: float = 2.0  ## Zucken während der Vorwarnung

@onready var _model: Node3D = $Model
@onready var _bite_area: Area3D = $BiteArea
@onready var _mouth_point: Marker3D = $MouthPoint   # Stelle im Maul, an der der Spieler steckt
@onready var _back_point: Marker3D = $BackPoint     # Landepunkt nach dem Befreien

var _anim_player: AnimationPlayer
var _state := State.CLOSED
var _time_left := 0.0
var _rest: Transform3D
var _victim: Node3D
var _presses := 0

# Aufbäumen: 0 = liegt normal, 1 = steht senkrecht mit dem Maul am Spieler
var _rear_amount := 0.0
var _rear_active := false
var _grab_point := Vector3.ZERO   # Füße des Spielers, lokal zum Krokodil
var _sink := 0.0
var _rear_tween: Tween


func _ready() -> void:
	_rest = _model.transform
	_anim_player = _find_bite_player()
	_bite_area.body_entered.connect(_on_bite_area_body_entered)
	_time_left = closed_time + start_delay


func is_open() -> bool:
	return _state == State.OPEN


func _find_bite_player() -> AnimationPlayer:
	for p in _model.find_children("*", "AnimationPlayer", true, false):
		if (p as AnimationPlayer).has_animation(bite_animation):
			return p
	return null


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _rear_active:
		_apply_rear()
	if _state == State.GRABBED:
		_process_grab()
		return
	if _state == State.SWALLOWED:
		return
	if _state == State.WARNING and not _rear_active:
		# Zucken um die Längsachse
		var phase := (warning_time - _time_left) / maxf(warning_time, 0.01)
		_model.rotation.z = _rest.basis.get_euler().z + deg_to_rad(shake_degrees) * sin(phase * TAU * 3.0)
	if _time_left > 0.0:
		return
	match _state:
		State.CLOSED:
			_state = State.WARNING
			_time_left = warning_time
		State.WARNING:
			_open()
		State.OPEN:
			_close()


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
	_time_left = closed_time
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
	_presses = 0
	_state = State.GRABBED
	_time_left = struggle_time
	# Der Spieler bleibt, wo er ist - das Krokodil kommt zu ihm.
	if _victim.has_method("capture"):
		_victim.capture()
	else:
		_victim.set_physics_process(false)
	_grab_point = to_local(_victim.global_position)
	_sink = 0.0
	_rear_active = true
	_tween_rear(1.0, rear_up_time, Tween.EASE_OUT)
	GameState.show_message(escape_hint)


# ---------- Aufbäumen ----------

## Setzt das Modell zwischen Ruhelage und "senkrecht, Maul am Spieler".
func _apply_rear() -> void:
	# Kopf (+Z des Modells) zeigt nach oben, dazu Drehen um die Hochachse (Schütteln)
	var thrash := 0.0
	if _state == State.GRABBED:
		thrash = deg_to_rad(thrash_degrees) * sin(_time_left * TAU * 2.5) * _rear_amount
	var upright := Basis(Vector3.UP, thrash) * Basis(Vector3.RIGHT, -PI / 2.0)
	var mouth_local := _mouth_point.position   # Maulpunkt in der Ruhelage
	var origin := _grab_point - upright * mouth_local + Vector3.DOWN * _sink
	var reared := Transform3D(upright, origin)
	_model.transform = _rest.interpolate_with(reared, _rear_amount)
	if _rear_amount <= 0.0 and _state != State.GRABBED and _state != State.SWALLOWED:
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
	if Input.is_action_just_pressed("jump"):
		_presses += 1
		if _presses >= presses_to_escape:
			_release_victim()
			return
	if _time_left <= 0.0:
		_swallow()


func _release_victim() -> void:
	GameState.show_message("")
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


func _swallow() -> void:
	_state = State.SWALLOWED
	GameState.show_message("")
	mouth_closed.emit()
	if _anim_player:
		_anim_player.play_backwards(bite_animation)   # Maul schnappt zu
	_victim.visible = false
	# senkrecht abtauchen
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "_sink", swallow_sink, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	GameState.player_died(_victim, 1.0)
