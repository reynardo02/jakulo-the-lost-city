extends Node3D
## Schlafender Affe im Sumpf (Level 3). Am Affen schleicht man geduckt vorbei:
## - Schritte füllen die Anzeige über dem Affen ("?"). Stillstehen ist leise.
##   Schleichen erzeugt sehr leise Schritte; harte Landungen sind deutlich hörbar.
## - Laute Geräusche (knackender Ast, Platschen ins Wasser) wecken ihn sofort, wenn sie in
##   ihrem Radius passieren. Sie kommen über die Gruppe "sleeper" an: hear_noise().
##
## Wach verhält er sich wie ein echtes Tier statt wie ein Geschützturm:
## erschrecken -> sich orientieren und zum Spieler drehen (mit Tippelschritten) ->
## wütend drohen -> bücken und einen Stein greifen -> kurz zielen -> werfen.
## Der Stein fliegt auf einer echten Wurfparabel auf die Stelle, an der der Spieler beim
## Loslassen war. Wer sich bewegt, weicht aus. Steine prallen ab, bleiben liegen oder
## platschen ins Wasser. Ein Treffer kostet höchstens ein Leben pro Aufwachen und stößt
## zurück. Danach sucht der Affe noch kurz die Umgebung ab, dreht sich zurück und schläft ein.
##
## Aufbau: Model (Node3D mit monkey_animator.gd und dem geriggten Affen).

@export var hear_radius: float = 8.0        ## so nah hört er einen Spieler, der nicht schleicht
@export var wake_time: float = 1.0          ## Sekunden Lärm (laufend), bis er aufwacht
@export var calm_time: float = 2.0          ## Sekunden, bis eine volle Anzeige wieder leer ist
@export var throw_range: float = 16.0       ## so weit wirft er
@export var throws: int = 3                 ## Würfe pro Aufwachen (endet früher, wenn der Spieler schleicht)
@export var throw_speed: float = 1.3        ## Abspielgeschwindigkeit der Wurfanimation
@export var knockback: float = 5.0          ## m/s Rückstoß bei einem Treffer
@export var aim_error: float = 0.3          ## Streuung des Wurfs in Metern
@export var turn_speed: float = 2.6         ## rad/s, so schnell dreht er sich um
@export var note_id: String = "monkey"

@export_group("Wurfanimation")
## Zeitpunkte in der Animation "throw" (Sekunden bei Tempo 1). Die Animation endet mit
## einem Bücken zum Boden: dort greift der Affe den nächsten Stein.
@export var release_time: float = 2.5       ## der Stein verlässt die Hand
@export var pickup_start: float = 3.35      ## ab hier bückt er sich
@export var grab_time: float = 3.7          ## Hand am Boden: Stein ist gegriffen

const HURT_SOUND := preload("res://assets/music/sounds/hurt.wav")
const WHOOSH_SOUND := preload("res://assets/music/sounds/stone_whoosh.wav")
const HIT_SOUNDS := [preload("res://assets/music/sounds/stone_hit.wav"), preload("res://assets/music/sounds/stone_hit_2.wav")]
const SPLASH_SOUND := preload("res://assets/music/sounds/stone_splash.wav")
const WATER_RING := preload("res://scripts/water_ring.gd")
const GRAVITY := 9.8
const STONE_RADIUS := 0.1
const HAND_BONE := &"RightHand"
const CHEST := 0.9   # Trefferpunkt über den Füßen des Spielers

enum State { ASLEEP, STARTLED, ANGRY, PICKUP, AIM, THROW, SEARCH, SETTLING }

@onready var _model: Node3D = $Model

var noise := 0.0   # 0 .. 1
var _state := State.ASLEEP
var _player: CharacterBody3D
var _throws_left := 0
var _wait := 0.0
var _anim_t := 0.0          # Position in der Wurfanimation (Sekunden bei Tempo 1)
var _anim_speed := 1.0
var _released := false
var _rest_yaw := 0.0
var _search_yaw := 0.0
var _turning := false
var _zzz: Label3D
var _mark: Label3D
var _t := 0.0
var _skeleton: Skeleton3D
var _hand := -1
var _held: MeshInstance3D   # Stein in der Hand
var _stones: Array[Dictionary] = []

static var _stone_mesh: Mesh
static var _grace_until := 0   # ms: bis dahin richten Steine keinen Schaden an (nach einem Treffer)
var _calm_until := 0           # ms: so lange ist dieser Affe nach einem Treffer zufrieden und schläft fest

const GRACE_AFTER_HIT := 3.0
const CALM_AFTER_HIT := 12.0


func _ready() -> void:
	add_to_group("sleeper")
	_rest_yaw = _model.rotation.y
	_zzz = _label("z Z", 48, Color(0.85, 0.9, 1.0, 0.85))
	_mark = _label("?", 96, Color(1.0, 0.9, 0.2))
	_mark.visible = false
	_t = randf() * TAU
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0]
		_hand = _skeleton.find_bone(HAND_BONE)
	_held = _make_stone()
	_held.top_level = true
	_held.visible = false
	add_child(_held)
	_anim(&"sleep", 0.0)


func _label(text: String, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.modulate = color
	label.outline_size = 12
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0, 1.4, 0)
	add_child(label)
	return label


func _anim(anim_name: StringName, blend: float = 0.3, speed: float = 1.0) -> float:
	if _model.has_method("play_anim"):
		return _model.play_anim(anim_name, blend, speed)
	return 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	match _state:
		State.ASLEEP:
			_sleep(delta)
		State.SETTLING:
			_settle(delta)
		_:
			_awake(delta)
	_update_held_stone()
	_update_stones(delta)


# ---------- Schlafen ----------

func _sleep(delta: float) -> void:
	_zzz.position.y = 1.2 + fmod(_t * 0.25, 0.5)
	var rate := 0.0
	if is_instance_valid(_player) and _player.is_physics_processing():
		var flat := _player.global_position - global_position
		flat.y = 0.0
		if flat.length() < hear_radius + 4.0:
			GameState.unlock_note(note_id)
		if flat.length() <= hear_radius and Time.get_ticks_msec() >= _calm_until:
			rate = _loudness(_player) / wake_time
	if rate > 0.0:
		noise = minf(noise + rate * delta, 1.0)
	else:
		noise = maxf(noise - delta / calm_time, 0.0)
	_mark.visible = noise > 0.05
	_mark.modulate = Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.15, 0.1), noise)
	if noise >= 1.0:
		wake()


## Hörbare Schrittimpulse stammen aus dem gemeinsamen Foley-System.
func _loudness(player: CharacterBody3D) -> float:
	return float(player.call("movement_loudness")) if player.has_method("movement_loudness") else 0.0


## Ein lautes Geräusch (knackender Ast, Platschen). Weckt sofort, wenn es nah genug war.
func hear_noise(origin: Vector3, radius: float) -> void:
	if _state == State.ASLEEP and global_position.distance_to(origin) <= radius:
		wake()


func wake() -> void:
	if _state != State.ASLEEP or Time.get_ticks_msec() < _calm_until:
		return
	noise = 1.0
	_zzz.visible = false
	_mark.visible = true
	_mark.text = "!"
	_mark.modulate = Color(1.0, 0.15, 0.1)
	GameState.unlock_note(note_id)
	_throws_left = throws
	# Erschrecken: hochfahren und kurz orientieren, bevor er reagiert
	_state = State.STARTLED
	_anim(&"idle", 0.2, 1.4)
	_wait = randf_range(0.35, 0.6)


# ---------- Wach ----------

func _awake(delta: float) -> void:
	_wait -= delta
	match _state:
		State.STARTLED:
			_turn_to(_yaw_to_player(), turn_speed * 0.6, delta, false)
			if _wait <= 0.0:
				_state = State.ANGRY
				_wait = _anim(&"angry", 0.2, 1.0)   # drohen: aufstampfen, Brust trommeln
		State.ANGRY:
			_turn_to(_yaw_to_player(), turn_speed * 0.5, delta, false)
			if _wait <= 0.0:
				_next_action()
		State.PICKUP:
			_advance_throw_anim(delta)
			if _anim_t >= grab_time and not _held.visible:
				_held.visible = true
			if _anim_t >= _throw_length():
				# Stein in der Hand: aufrichten, Ziel suchen
				_state = State.AIM
				_anim(&"idle", 0.35, 1.0)
				_wait = randf_range(0.25, 0.6)
		State.AIM:
			var diff := _turn_to(_yaw_to_player(), turn_speed, delta, true)
			if not _player_targetable() or _throws_left <= 0:
				_drop_and_search()
			elif _wait <= 0.0 and absf(diff) < 0.35:
				_start_throw()
		State.THROW:
			_advance_throw_anim(delta)
			if not _released:
				# Bis zum Loslassen korrigiert er die Richtung noch leicht
				_turn_to(_yaw_to_player(), turn_speed * 0.4, delta, false)
				if _anim_t >= release_time:
					_release()
			elif _anim_t >= pickup_start:
				if _throws_left > 0 and _player_targetable():
					_state = State.PICKUP   # die Animation bückt sich ohnehin: gleich nachladen
				else:
					_start_search()
		State.SEARCH:
			# sich umsehen: langsam nach links und rechts schwenken
			var look := _search_yaw + sin(_t * 1.3) * 0.6
			_turn_to(look, turn_speed * 0.35, delta, false)
			if _player_targetable() and _throws_left > 0 and _loudness(_player) > 0.2:
				_next_action()
			elif _wait <= 0.0:
				_fall_asleep()


func _next_action() -> void:
	if _throws_left > 0 and _player_targetable():
		_state = State.PICKUP
		_anim(&"throw", 0.3, 1.0)
		_anim_speed = 1.0
		_model.call("seek_anim", pickup_start)
		_anim_t = pickup_start
	else:
		_start_search()


func _start_throw() -> void:
	_throws_left -= 1
	_state = State.THROW
	_released = false
	_turning = false
	_anim_speed = throw_speed * randf_range(0.9, 1.1)
	_anim(&"throw", 0.15, _anim_speed)
	_model.call("seek_anim", 0.0)
	_anim_t = 0.0


func _advance_throw_anim(delta: float) -> void:
	_anim_t += delta * _anim_speed


func _throw_length() -> float:
	var length: float = _model.call("anim_length", &"throw") if _model.has_method("anim_length") else 0.0
	return length if length > 0.0 else 4.3


func _player_targetable() -> bool:
	if not is_instance_valid(_player) or not _player.is_physics_processing():
		return false
	var dist := _player.global_position.distance_to(global_position)
	if dist > throw_range:
		return false
	# Wer sich duckt und außer Hörweite ist, ist für ihn verschwunden
	return not (_player.get("is_sneaking") == true and dist > hear_radius)


func _drop_and_search() -> void:
	if _held.visible:
		_held.visible = false
		_launch(_held.global_position, Vector3(randf_range(-0.5, 0.5), 0.5, randf_range(-0.5, 0.5)), false)
	_start_search()


func _start_search() -> void:
	_state = State.SEARCH
	_turning = false
	_anim(&"idle", 0.4, 1.0)
	_search_yaw = _model.rotation.y
	_wait = randf_range(1.6, 2.6)


func _fall_asleep() -> void:
	_state = State.SETTLING
	_mark.visible = false
	_mark.text = "?"
	_held.visible = false


func _settle(delta: float) -> void:
	var diff := _turn_to(_rest_yaw, turn_speed * 0.6, delta, true)
	if absf(diff) < 0.08 and not _turning:
		_model.rotation.y = _rest_yaw
		_anim(&"sleep", 1.2)
		noise = 0.0
		_zzz.visible = true
		_state = State.ASLEEP


# ---------- Drehen ----------

func _yaw_to_player() -> float:
	if not is_instance_valid(_player):
		return _model.rotation.y
	var to_player := _player.global_position - global_position
	return atan2(to_player.x, to_player.z) - global_rotation.y


## Dreht mit begrenzter Geschwindigkeit (kein Gleiten wie ein Turm). Bei großen Winkeln
## und `step` tippelt der Affe mit der Laufanimation herum. Gibt die Restabweichung zurück.
func _turn_to(target: float, speed: float, delta: float, step: bool) -> float:
	var diff := wrapf(target - _model.rotation.y, -PI, PI)
	var turn := clampf(diff, -speed * delta, speed * delta)
	# weich anlaufen und abbremsen
	turn *= clampf(absf(diff) / 0.4, 0.25, 1.0)
	_model.rotation.y += turn
	if step:
		if absf(diff) > 0.45 and not _turning:
			_turning = true
			_anim(&"walking", 0.25, 0.9)
		elif absf(diff) < 0.12 and _turning:
			_turning = false
			_anim(&"idle", 0.3, 1.0)
	return wrapf(target - _model.rotation.y, -PI, PI)


# ---------- Steine ----------

func _hand_position() -> Vector3:
	if _skeleton and _hand >= 0:
		return _skeleton.global_transform * _skeleton.get_bone_global_pose(_hand).origin
	return global_position + Vector3.UP * 1.0


func _update_held_stone() -> void:
	if _held.visible:
		_held.global_position = _hand_position()


func _release() -> void:
	_released = true
	if not _held.visible:
		return
	_held.visible = false
	if not _player_targetable():
		return
	var from := _hand_position()
	var target := _player.global_position + Vector3.UP * CHEST
	target += Vector3(randf_range(-1, 1), randf_range(-0.5, 0.5), randf_range(-1, 1)).normalized() * randf() * aim_error
	var flat := Vector2(target.x - from.x, target.z - from.z).length()
	var flight := clampf(0.45 + flat * 0.05, 0.55, 1.2)
	# Wurfparabel: Startgeschwindigkeit, die nach `flight` Sekunden am Ziel ankommt
	var velocity := (target - from) / flight + Vector3.UP * 0.5 * GRAVITY * flight
	_launch(from, velocity, true)
	_sound_at(WHOOSH_SOUND, from, -10.0, randf_range(0.9, 1.1))


func _make_stone() -> MeshInstance3D:
	if _stone_mesh == null:
		var sphere := SphereMesh.new()
		sphere.radius = STONE_RADIUS
		sphere.height = STONE_RADIUS * 1.6
		sphere.radial_segments = 7
		sphere.rings = 4
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.43, 0.41, 0.37)
		mat.roughness = 0.95
		sphere.material = mat
		_stone_mesh = sphere
	var stone := MeshInstance3D.new()
	stone.mesh = _stone_mesh
	stone.scale = Vector3(randf_range(0.9, 1.15), randf_range(0.75, 1.0), randf_range(0.8, 1.1))
	stone.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	return stone


func _launch(from: Vector3, velocity: Vector3, harmful: bool) -> void:
	var stone := _make_stone()
	get_tree().current_scene.add_child(stone)
	stone.global_position = from
	_stones.append({
		"node": stone, "vel": velocity, "spin": Vector3(randf_range(-12, 12), randf_range(-6, 6), randf_range(-12, 12)),
		"harmful": harmful, "age": 0.0, "rest": -1.0, "sinking": false,
	})


func _water_height() -> float:
	var water := get_tree().current_scene.get_node_or_null("Wasser") as Node3D
	return water.global_position.y if water else -INF


func _update_stones(delta: float) -> void:
	if _stones.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var water_y := _water_height()
	for s in _stones.duplicate():
		var stone := s["node"] as MeshInstance3D
		if not is_instance_valid(stone):
			_stones.erase(s)
			continue
		s["age"] += delta
		if s["rest"] >= 0.0:
			# liegt: nach einer Weile im Boden versinken lassen
			s["rest"] += delta
			if s["rest"] > 5.0:
				stone.global_position.y -= delta * 0.3
			if s["rest"] > 6.0:
				stone.queue_free()
				_stones.erase(s)
			continue
		if s["sinking"]:
			stone.global_position.y -= delta * 0.8
			if s["age"] > 1.5:
				stone.queue_free()
				_stones.erase(s)
			continue
		var vel: Vector3 = s["vel"]
		var from := stone.global_position
		vel.y -= GRAVITY * delta
		var to := from + vel * delta
		stone.rotation += s["spin"] * delta
		# Spieler: Treffer, wenn die Flugbahn nah genug an der Brust vorbeigeht
		if s["harmful"] and is_instance_valid(_player) and _player.is_physics_processing():
			var chest := _player.global_position + Vector3.UP * CHEST
			if Geometry3D.get_closest_point_to_segment(chest, from, to).distance_to(chest) < 0.5:
				_hit_player(stone.global_position)
				s["harmful"] = false
				vel = -vel * 0.2
				to = from
		# Wasser
		if from.y >= water_y and to.y < water_y:
			var point := from.lerp(to, (from.y - water_y) / maxf(from.y - to.y, 0.001))
			stone.global_position = point
			_splash(point)
			s["sinking"] = true
			s["age"] = 0.0
			continue
		# Boden und Hindernisse
		var query := PhysicsRayQueryParameters3D.create(from, to + vel.normalized() * STONE_RADIUS, 1)
		if is_instance_valid(_player):
			var skip: Array[RID] = [_player.get_rid()]
			query.exclude = skip
		var hit := space.intersect_ray(query)
		if hit:
			var normal: Vector3 = hit["normal"]
			stone.global_position = hit["position"] + normal * STONE_RADIUS
			var speed := vel.length()
			if speed > 1.2:
				_sound_at(HIT_SOUNDS.pick_random(), stone.global_position, linear_to_db(clampf(speed / 9.0, 0.15, 1.0)) - 4.0, randf_range(0.85, 1.15))
			vel = vel.bounce(normal) * 0.35
			s["spin"] = s["spin"] * 0.5
			s["harmful"] = false
			if vel.length() < 1.0 or s["age"] > 4.0:
				s["rest"] = 0.0
		else:
			stone.global_position = to
		s["vel"] = vel
		if s["age"] > 6.0:
			stone.queue_free()
			_stones.erase(s)


func _hit_player(point: Vector3) -> void:
	_throws_left = 0   # getroffen: der Affe gibt Ruhe – höchstens ein Leben pro Aufwachen
	_calm_until = Time.get_ticks_msec() + int(CALM_AFTER_HIT * 1000.0)
	# Schonfrist für alle Affen: kein zweiter Treffer kurz nach dem ersten
	if Time.get_ticks_msec() < _grace_until:
		return
	_grace_until = Time.get_ticks_msec() + int(GRACE_AFTER_HIT * 1000.0)
	_sound_at(HURT_SOUND, point, 0.0)
	var push := _player.global_position - global_position
	push.y = 0.0
	if _player.has_method("knockback"):
		_player.knockback(push.normalized() * knockback)
	GameState.hurt(_player, "Getroffen! Die Affen werfen mit Steinen.")


func _splash(point: Vector3) -> void:
	_sound_at(SPLASH_SOUND, point, -6.0, randf_range(0.9, 1.15))
	var ring := MeshInstance3D.new()
	ring.set_script(WATER_RING)
	get_tree().current_scene.add_child(ring)
	ring.global_position = point + Vector3.UP * 0.02
	ring.scale = Vector3.ONE * 0.6


func _sound_at(stream: AudioStream, point: Vector3, db: float, pitch := 1.0) -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.bus = &"Sounds"
	sound.volume_db = db
	sound.pitch_scale = pitch
	sound.unit_size = 6.0
	sound.max_distance = 40.0
	get_tree().current_scene.add_child(sound)
	sound.global_position = point
	sound.finished.connect(sound.queue_free)
	sound.play()
