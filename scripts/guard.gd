extends AnimatableBody3D
## Wache im Dorf der Ureinwohner.
## Sieht in einem Sichtkegel nach vorn (+Z der Szene) und hört einen Spieler, der in ihrer
## Nähe nicht schleicht. Solange sie den Spieler wahrnimmt, steigt ihre Entdeckungsanzeige;
## ist sie voll, verfolgt sie ihn. Erst bei Sichtkontakt in Greifnähe wird er gefangen.
## Wer geduckt im hohen Gras steckt (Player.is_hidden()), wird nur aus nächster Nähe bemerkt.
##
## Steht fest oder patrouilliert zwischen ihrem Startpunkt und Start + `patrol_offset`.

@export_group("Wahrnehmung")
@export var view_distance: float = 11.0       ## Reichweite des Sichtkegels in Metern
@export var view_angle: float = 35.0          ## halber Öffnungswinkel des Sichtkegels in Grad
@export var hear_radius: float = 3.5          ## so nah hört sie einen Spieler, der nicht schleicht
@export var touch_radius: float = 1.3         ## so nah bemerkt sie jeden, auch versteckt und von hinten
@export var detect_time_near: float = 0.5     ## Sekunden bis zur Entdeckung direkt vor der Wache
@export var detect_time_far: float = 2.0      ## ... und am Rand der Sichtweite
@export var sneak_factor: float = 0.6         ## Schleichen bremst die Anzeige auf diesen Anteil
@export var forget_time: float = 2.0          ## Sekunden, bis eine volle Anzeige wieder leer ist
@export var costs_life: bool = false          ## an = Entdeckung kostet ein Leben wie jeder andere Tod
@export var note_id: String = "natives"       ## Notiz im Buch, sobald der Spieler der Wache nahe kommt
@export var show_view_cone: bool = true
@export var search_duration: float = 4.0
@export var chase_speed: float = 3.6
@export var pursuit_radius: float = 12.0

enum Awareness { PATROL, INVESTIGATE, CHASE, SEARCH, RETURN }
var awareness := Awareness.PATROL
var _last_known := Vector3.ZERO
var _search_left := 0.0
var _sees_player := false
var _heard_until := 0

@export_group("Patrouille")
@export var patrol_offset: Vector3 = Vector3.ZERO  ## Ziel der Patrouille relativ zum Start (0 = steht fest)
@export var patrol_speed: float = 1.6
@export var patrol_pause: float = 1.5         ## Wartezeit an beiden Enden
@export var turn_speed: float = 3.0           ## rad/s beim Umdrehen
@export var look_sweep: float = 0.0           ## feste Wache: schwenkt den Blick um so viele Grad hin und her
@export var look_sweep_time: float = 6.0      ## Dauer eines ganzen Schwenks

@export_group("Animation")
@export var walk_animation: StringName = &"Walk"
@export var idle_animation: StringName = &"Idle"

const EYE_HEIGHT := 1.5

@onready var _model: Node3D = $Model
@onready var _mark: Label3D = $Mark

var detection := 0.0   # 0 .. 1

var _anim: AnimationPlayer
var _cone: MeshInstance3D
var _cone_material: StandardMaterial3D
var _player: Node3D
var _start := Vector3.ZERO
var _base_yaw := 0.0
var _to_end := true
var _pause_left := 0.0
var _time := 0.0
var _caught := false


func _ready() -> void:
	add_to_group("guards")
	_start = global_position
	_base_yaw = rotation.y
	for p in _model.find_children("*", "AnimationPlayer", true, false):
		_anim = p
		break
	for animation in [walk_animation, idle_animation]:
		if _anim and _anim.has_animation(animation):
			_anim.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
	_build_cone()
	_play(idle_animation)


func _exit_tree() -> void:
	GameState.report_detection(self, 0.0)


func _physics_process(delta: float) -> void:
	if _caught:
		return
	_time += delta
	_perceive(delta)
	if not _caught:
		_move(delta)


# ---------- Bewegung ----------

func _move(delta: float) -> void:
	if awareness != Awareness.PATROL:
		_alert_move(delta)
		return
	if patrol_offset.length_squared() < 0.01:
		if look_sweep > 0.0:
			rotation.y = _base_yaw + deg_to_rad(look_sweep) * sin(_time * TAU / look_sweep_time)
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		_play(idle_animation)
		return
	var target := _start + patrol_offset if _to_end else _start
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.1:
		_to_end = not _to_end
		_pause_left = patrol_pause
		return
	# erst in Laufrichtung drehen, dann gehen
	var want_yaw := atan2(to_target.x, to_target.z)
	rotation.y = rotate_toward(rotation.y, want_yaw, turn_speed * delta)
	if absf(angle_difference(rotation.y, want_yaw)) > 0.3:
		_play(idle_animation)
		return
	_safe_step(to_target.normalized() * minf(patrol_speed * delta, to_target.length()))
	_play(walk_animation)


func _play(animation: StringName) -> void:
	if _anim and _anim.has_animation(animation) and _anim.current_animation != animation:
		_anim.play(animation, 0.25)


# ---------- Wahrnehmung ----------

func _perceive(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	var noticed := 0.0   # Anstieg pro Sekunde
	_sees_player = false
	if is_instance_valid(_player) and _player.is_physics_processing():
		noticed = _notice_rate()
	else:
		return
	if noticed > 0.0:
		detection = minf(detection + noticed * delta, 1.0)
	else:
		detection = maxf(detection - delta / forget_time, 0.0)
	if _sees_player:
		_last_known = _player.global_position
		_search_left = search_duration
		if detection >= 1.0:
			awareness = Awareness.CHASE
		elif detection > 0.2 and awareness != Awareness.CHASE:
			awareness = Awareness.INVESTIGATE
	elif awareness == Awareness.CHASE:
		awareness = Awareness.INVESTIGATE
	GameState.report_detection(self, detection)
	_update_signs()
	if detection >= 0.7 and global_position.distance_to(_player.global_position) <= touch_radius and _has_line_of_sight(_player.get("is_sneaking") == true):
		_caught = true
		_mark.text = "!"
		_play(idle_animation)
		GameState.player_caught(_player, costs_life)


## Wie schnell die Anzeige gerade steigt (0 = Spieler wird nicht wahrgenommen).
func _notice_rate() -> float:
	var to_player := _player.global_position - global_position
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	var dist := flat.length()
	if dist < view_distance + 4.0:
		GameState.unlock_note(note_id)
	var sneaking: bool = _player.get("is_sneaking") == true
	var hidden: bool = _player.has_method("is_hidden") and _player.is_hidden()
	if dist <= touch_radius:
		if _has_line_of_sight(sneaking) and absf(to_player.y) < 2.0:
			_sees_player = true
			return 1.0 / detect_time_near
	if hidden:
		return 0.0
	var rate := 0.0
	if dist <= view_distance and dist > 0.01:
		var angle := rad_to_deg(global_basis.z.normalized().angle_to(flat.normalized()))
		if angle <= view_angle and _has_line_of_sight(sneaking):
			_sees_player = true
			rate = 1.0 / lerpf(detect_time_near, detect_time_far, dist / view_distance)
			if sneaking:
				rate *= sneak_factor
	if Time.get_ticks_msec() < _heard_until:
		rate = maxf(rate, 1.0 / lerpf(detect_time_near, detect_time_far, 0.5))
	return rate

func hear_noise(origin: Vector3, radius: float) -> void:
	if _caught or global_position.distance_to(origin) > radius * hear_radius / 5.0:
		return
	if awareness == Awareness.CHASE:
		return
	_last_known = origin
	_heard_until = Time.get_ticks_msec() + 450
	_search_left = search_duration
	awareness = Awareness.INVESTIGATE

func _safe_step(motion: Vector3) -> bool:
	# Do not walk through huts or step into water/pits while investigating.
	if test_move(global_transform, motion):
		return false
	var ahead := global_position + motion.normalized() * 0.65
	var query := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.5, ahead + Vector3.DOWN * 0.8, 1)
	query.exclude = [get_rid()]
	if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return false
	global_position += motion
	return true

func _alert_move(delta: float) -> void:
	if awareness == Awareness.SEARCH:
		_search_left -= delta
		rotation.y += sin(_time * 1.8) * delta
		_play(idle_animation)
		if _search_left <= 0.0:
			awareness = Awareness.RETURN
		return
	var patrol_end := _start + patrol_offset
	var nearest := Geometry3D.get_closest_point_to_segment(global_position, _start, patrol_end) if patrol_offset.length_squared() > 0.01 else _start
	if global_position.distance_to(nearest) > pursuit_radius:
		awareness = Awareness.RETURN
	var target := _start if awareness == Awareness.RETURN else _last_known
	var offset := target - global_position
	offset.y = 0.0
	if offset.length() < 0.5:
		if awareness == Awareness.RETURN:
			awareness = Awareness.PATROL
			rotation.y = _base_yaw
		else:
			awareness = Awareness.SEARCH
			_search_left = search_duration
		_play(idle_animation)
		return
	rotation.y = rotate_toward(rotation.y, atan2(offset.x, offset.z), turn_speed * delta)
	var speed := chase_speed if awareness == Awareness.CHASE else patrol_speed
	if _safe_step(offset.normalized() * minf(offset.length(), speed * delta)):
		_play(walk_animation)
	else:
		_play(idle_animation)
		if awareness != Awareness.RETURN:
			awareness = Awareness.SEARCH
			_search_left = search_duration


func _has_line_of_sight(sneaking: bool) -> bool:
	var from := global_position + Vector3.UP * EYE_HEIGHT
	var to := _player.global_position + Vector3.UP * (0.7 if sneaking else 1.2)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var exclude: Array[RID] = [get_rid()]
	if _player is CollisionObject3D:
		exclude.append((_player as CollisionObject3D).get_rid())
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# ---------- Anzeige ----------

func _update_signs() -> void:
	_mark.visible = detection > 0.05 or awareness in [Awareness.SEARCH, Awareness.CHASE]
	_mark.text = "!" if awareness == Awareness.CHASE else "?"
	_mark.modulate = Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.15, 0.1), detection)
	_cone_material.albedo_color = Color(1.0, 0.9, 0.3, 0.16).lerp(Color(1.0, 0.1, 0.05, 0.4), detection)


## Sichtkegel als flacher Fächer knapp über dem Boden.
func _build_cone() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 16
	var half := deg_to_rad(view_angle)
	for i in steps:
		var a0 := lerpf(-half, half, float(i) / steps)
		var a1 := lerpf(-half, half, float(i + 1) / steps)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(sin(a1), 0.0, cos(a1)) * view_distance)
		st.add_vertex(Vector3(sin(a0), 0.0, cos(a0)) * view_distance)
	_cone_material = StandardMaterial3D.new()
	_cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_material.albedo_color = Color(1.0, 0.9, 0.3, 0.16)
	_cone = MeshInstance3D.new()
	_cone.mesh = st.commit()
	_cone.material_override = _cone_material
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.position.y = 0.45   # über den Grashalmen, sonst verschwindet er darin
	add_child(_cone)
	_cone.visible = show_view_cone
