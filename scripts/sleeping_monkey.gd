extends Node3D
## Schlafender Affe im Sumpf (Level 3). Am Affen schleicht man geduckt vorbei:
## - Ist der Spieler aufrecht in `hear_radius` (auch wenn er nur dasteht), füllt sich die
##   Anzeige über dem Affen ("?"). Laufen füllt sie schneller. Geduckt bleibt man ungehört;
##   in der Luft (Sprung über einen Ast) zählt man ebenfalls nicht.
## - Laute Geräusche (knackender Ast, Platschen ins Wasser) wecken ihn sofort, wenn sie in
##   ihrem Radius passieren. Sie kommen über die Gruppe "sleeper" an: hear_noise().
## Wach stampft er wütend auf, dreht sich zum Spieler und wirft Früchte mit einer echten
## Wurfbewegung. Ein Treffer kostet ein Leben und stößt zurück, führt aber nicht zum
## Checkpoint. Danach legt er sich wieder schlafen.
##
## Aufbau: Model (Node3D mit monkey_animator.gd und dem geriggten Affen).

@export var hear_radius: float = 8.0        ## so nah hört er einen Spieler, der nicht schleicht
@export var wake_time: float = 1.0          ## Sekunden Lärm (laufend), bis er aufwacht
@export var standing_factor: float = 0.5    ## aufrecht stehen ist halb so laut wie laufen
@export var calm_time: float = 2.0          ## Sekunden, bis eine volle Anzeige wieder leer ist
@export var throw_range: float = 16.0       ## so weit wirft er
@export var throws: int = 3                 ## Würfe pro Aufwachen (endet früher, wenn der Spieler schleicht)
@export var throw_speed: float = 1.8        ## Abspielgeschwindigkeit der Wurfanimation
@export var release_at: float = 0.55        ## Anteil der Wurfanimation, bei dem die Frucht losfliegt
@export var fruit_flight_time: float = 0.75
@export var knockback: float = 5.0          ## m/s Rückstoß bei einem Treffer
@export var note_id: String = "monkey"

const FRUIT_MODEL := "res://assets/props/banana.glb"
const HURT_SOUND := "res://assets/music/sounds/hurt.wav"
const HAND_HEIGHT := 1.0

enum State { ASLEEP, WAKING, AWAKE, THROWING, SETTLING }

@onready var _model: Node3D = $Model

var noise := 0.0   # 0 .. 1
var _state := State.ASLEEP
var _player: CharacterBody3D
var _throws_left := 0
var _wait := 0.0
var _rest_yaw := 0.0
var _zzz: Label3D
var _mark: Label3D
var _sound: AudioStreamPlayer3D
var _t := 0.0


func _ready() -> void:
	add_to_group("sleeper")
	_rest_yaw = _model.rotation.y
	_zzz = _label("z Z", 48, Color(0.85, 0.9, 1.0, 0.85))
	_mark = _label("?", 96, Color(1.0, 0.9, 0.2))
	_mark.visible = false
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = load(HURT_SOUND)
	_sound.bus = &"Sounds"
	add_child(_sound)
	_t = randf() * TAU
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
		State.WAKING, State.AWAKE, State.THROWING:
			_awake(delta)


# ---------- Schlafen ----------

func _sleep(delta: float) -> void:
	_zzz.position.y = 1.2 + fmod(_t * 0.25, 0.5)
	var rate := 0.0
	if is_instance_valid(_player) and _player.is_physics_processing():
		var flat := _player.global_position - global_position
		flat.y = 0.0
		if flat.length() < hear_radius + 4.0:
			GameState.unlock_note(note_id)
		if flat.length() <= hear_radius:
			rate = _loudness(_player) / wake_time
	if rate > 0.0:
		noise = minf(noise + rate * delta, 1.0)
	else:
		noise = maxf(noise - delta / calm_time, 0.0)
	_mark.visible = noise > 0.05
	_mark.modulate = Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.15, 0.1), noise)
	if noise >= 1.0:
		wake()


## 0 = leise (geduckt oder in der Luft), sonst 1 beim Laufen, `standing_factor` im Stand.
func _loudness(player: CharacterBody3D) -> float:
	if player.get("is_sneaking") == true or not player.is_on_floor():
		return 0.0
	var moving := Vector2(player.velocity.x, player.velocity.z).length() > 0.5
	return 1.0 if moving else standing_factor


## Ein lautes Geräusch (knackender Ast, Platschen). Weckt sofort, wenn es nah genug war.
func hear_noise(origin: Vector3, radius: float) -> void:
	if _state == State.ASLEEP and global_position.distance_to(origin) <= radius:
		wake()


func wake() -> void:
	if _state != State.ASLEEP:
		return
	_state = State.WAKING
	noise = 1.0
	_zzz.visible = false
	_mark.visible = true
	_mark.text = "!"
	_mark.modulate = Color(1.0, 0.15, 0.1)
	GameState.unlock_note(note_id)
	_throws_left = throws
	_wait = _anim(&"angry", 0.2, 1.2)   # wütend aufstampfen, dann geht's los


# ---------- Wach ----------

func _awake(delta: float) -> void:
	_face_player(delta)
	_wait -= delta
	if _wait > 0.0:
		return
	var in_range: bool = is_instance_valid(_player) and _player.is_physics_processing() \
		and _player.global_position.distance_to(global_position) <= throw_range
	# Wer sich wieder duckt und verschwindet, wird in Ruhe gelassen
	var hidden: bool = in_range and _player.get("is_sneaking") == true \
		and _player.global_position.distance_to(global_position) > hear_radius
	if _throws_left > 0 and in_range and not hidden:
		_throws_left -= 1
		_throw()
	else:
		_fall_asleep()


func _face_player(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var to_player := _player.global_position - global_position
	var want := atan2(to_player.x, to_player.z) - global_rotation.y
	_model.rotation.y = lerp_angle(_model.rotation.y, want, 6.0 * delta)


func _throw() -> void:
	_state = State.THROWING
	var length := _anim(&"throw", 0.15, throw_speed)
	if length <= 0.0:
		length = 1.2
	_wait = length + 0.2
	var tween := create_tween()
	tween.tween_interval(length * release_at)
	tween.tween_callback(func() -> void:
		if is_instance_valid(_player) and _state == State.THROWING:
			_throw_fruit(_player.global_position))
	tween.tween_interval(length * (1.0 - release_at))
	tween.tween_callback(func() -> void:
		if _state == State.THROWING:
			_anim(&"idle", 0.3))


func _fall_asleep() -> void:
	_state = State.SETTLING
	_mark.visible = false
	_mark.text = "?"
	_anim(&"idle", 0.3)
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(_model, "rotation:y", _rest_yaw, 0.6)
	tween.tween_callback(func() -> void:
		_anim(&"sleep", 0.8)
		noise = 0.0
		_zzz.visible = true
		_state = State.ASLEEP)


## Wirft eine Frucht im Bogen auf die Stelle, an der der Spieler gerade steht.
## Wer sich bis zur Landung wegbewegt, weicht ihr aus.
func _throw_fruit(target: Vector3) -> void:
	var fruit := (load(FRUIT_MODEL) as PackedScene).instantiate() as Node3D
	get_tree().current_scene.add_child(fruit)
	fruit.scale = Vector3.ONE * 0.5
	var from := global_position + Vector3.UP * HAND_HEIGHT
	var to := target + Vector3.UP * 0.9
	var arc := 1.5 + from.distance_to(to) * 0.15
	fruit.global_position = from
	var tween := fruit.create_tween()
	tween.tween_method(func(s: float) -> void:
		if is_instance_valid(fruit):
			fruit.global_position = from.lerp(to, s) + Vector3.UP * arc * sin(PI * s)
			fruit.rotation.x = s * TAU * 2.0, 0.0, 1.0, fruit_flight_time)
	tween.tween_callback(func() -> void:
		_fruit_landed(to)
		fruit.queue_free())


func _fruit_landed(point: Vector3) -> void:
	if not is_instance_valid(_player) or not _player.is_physics_processing():
		return
	if (_player.global_position + Vector3.UP * 0.9).distance_to(point) > 1.1:
		return
	_sound.play()
	_throws_left = 0   # getroffen: der Affe gibt Ruhe – höchstens ein Leben pro Aufwachen
	var push := _player.global_position - global_position
	push.y = 0.0
	if _player.has_method("knockback"):
		_player.knockback(push.normalized() * knockback)
	GameState.hurt(_player, "Getroffen! Die Affen sind wach.")
