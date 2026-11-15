extends Node3D
## Prolog – Schiffbruch. Startszene des Spiels, danach geht es mit Level 1 weiter.
##
## Die Zeitleiste ist die Animation "prolog" im AnimationPlayer. Sie bewegt die Kamera und
## die Riffe, steuert über Wert-Spuren `storm` und `sea_volume` und ruft über eine
## Methoden-Spur die Funktionen unten auf (title, lightning, crash, hero_overboard, ...).
## Alles, was vom Sturm abhängt (Wellen, Himmel, Licht, Regen, Schwanken, Kamerawackeln,
## Geräusche), leitet _process() jedes Bild aus `storm` ab.
##
## Erzeugt wird die Szene von tools/cutscenes/build_prolog.gd; danach lässt sich alles
## normal im Editor bearbeiten. SPRINGEN oder BENUTZEN überspringt den Prolog.

const NEXT_SCENE := "res://scenes/level_1.tscn"
const ANIMATION := &"prolog"

## 0 = ruhige See, 1 = voller Sturm
@export_range(0.0, 1.0) var storm := 0.0
## Lautstärke von Meer und Regen (für die Schwarzblende: Wellen, dann Stille)
@export_range(0.0, 1.0) var sea_volume := 1.0
## Fahrt des Schiffs in m/s (verschiebt nur das Wellenmuster)
@export var ship_speed := 3.0

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _camera: Camera3D = $Camera
@onready var _rain: GPUParticles3D = $Camera/Rain
@onready var _sun: DirectionalLight3D = $Sun
@onready var _env: Environment = $WorldEnvironment.environment
@onready var _sea: MeshInstance3D = $Sea
@onready var _ship: Node3D = $Ship
@onready var _ship_hero: Node3D = $Ship/Hero
@onready var _map: Node3D = $Ship/Hero/Map
@onready var _crew: Node3D = $Ship/Crew   # Kapitän und Matrosen, nur auf dem Schiff
@onready var _reef: Node3D = $Reef
@onready var _beach: Node3D = $Beach
@onready var _beach_hero: Node3D = $Beach/Hero

# Farben: [Himmel oben, Horizont, Licht, Lichtstärke]
const EVENING := [Color(0.25, 0.33, 0.58), Color(0.98, 0.62, 0.36), Color(1.0, 0.68, 0.42), 1.3]
const STORM := [Color(0.07, 0.08, 0.11), Color(0.2, 0.23, 0.28), Color(0.55, 0.6, 0.72), 0.35]
const MORNING := [Color(0.33, 0.58, 0.85), Color(0.85, 0.86, 0.76), Color(1.0, 0.93, 0.8), 1.4]

var _t := 0.0
var _jolt := 0.0            # Stoß beim Auflaufen aufs Riff, klingt ab
var _flash := 0.0           # Blitz, klingt ab
var _on_beach := false
var _leaving := false
var _skip_ready := false
var _sea_offset := Vector2.ZERO
var _ship_base_y := 0.0

var _ui: CanvasLayer
var _fade: ColorRect
var _flash_rect: ColorRect
var _title: Label
var _hud_was_visible := true

# Geräusche (prozedural, es gibt noch keine Sturm-Samples)
const MIX_RATE := 16000.0
var _playback: AudioStreamGeneratorPlayback
var _lp_hiss := 0.0
var _lp_sea := 0.0
var _lp_sea2 := 0.0
var _lp_thunder := 0.0
var _wave_phase := 0.0
var _thunder := 0.0
var _thunder_delay := -1.0
var _birds := false
var _chirp_wait := 1.0
var _chirp_time := -1.0
var _chirp_phase := 0.0
var _chirp_base := 3000.0


func _ready() -> void:
	_ship_base_y = _ship.position.y
	_build_ui()
	_build_audio()
	if Music.playing:
		Music.stop()
	var hud := GameState.get_node_or_null("HUD") as CanvasLayer
	if hud:
		_hud_was_visible = hud.visible
		hud.visible = false
	_beach.visible = false
	_play_hero(_ship_hero, &"Idle_9", true)
	_lie_down(_beach_hero)
	_camera.make_current()
	_anim.animation_finished.connect(func(_name: StringName) -> void: _go_next())
	_anim.play(ANIMATION)
	get_tree().create_timer(0.6).timeout.connect(func() -> void: _skip_ready = true)


func _unhandled_input(event: InputEvent) -> void:
	if not _skip_ready or _leaving:
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_go_next()


func _process(delta: float) -> void:
	_t += delta
	_jolt = move_toward(_jolt, 0.0, delta * 0.6)
	_flash = move_toward(_flash, 0.0, delta * 4.0)
	var s := storm

	# Schiff schwankt: Rollen um die Längsachse (X), Stampfen um Z, Heben und Senken
	_ship.rotation.x = sin(_t * 0.9) * lerpf(0.02, 0.16, s) + _jolt * 0.35
	_ship.rotation.z = sin(_t * 0.6 + 1.0) * lerpf(0.01, 0.07, s) - _jolt * 0.12
	_ship.position.y = _ship_base_y + sin(_t * 1.1) * lerpf(0.15, 0.9, s) - _jolt * 0.8

	# Meer
	_sea_offset.x += ship_speed * delta * (0.0 if _on_beach else 1.0)
	var sea_mat := _sea.material_override as ShaderMaterial
	sea_mat.set_shader_parameter("wave_height", lerpf(0.35 if not _on_beach else 0.2, 1.8, s))
	sea_mat.set_shader_parameter("storm", s)
	sea_mat.set_shader_parameter("offset", _sea_offset)

	# Himmel und Licht
	var base: Array = MORNING if _on_beach else EVENING
	var sky := _env.sky.sky_material as ProceduralSkyMaterial
	var top: Color = (base[0] as Color).lerp(STORM[0], s)
	var horizon: Color = (base[1] as Color).lerp(STORM[1], s)
	sky.sky_top_color = top.lerp(Color(0.8, 0.85, 1.0), _flash * 0.7)
	sky.sky_horizon_color = horizon.lerp(Color(0.85, 0.9, 1.0), _flash * 0.7)
	sky.ground_horizon_color = horizon
	sky.ground_bottom_color = top.darkened(0.6)
	_sun.light_color = (base[2] as Color).lerp(STORM[2], s)
	_sun.light_energy = lerpf(base[3], STORM[3], s) + _flash * 3.0
	_env.fog_light_color = horizon
	_env.fog_density = lerpf(0.003, 0.02, s)

	# Regen ab mittlerem Sturm
	var rain := clampf((s - 0.3) / 0.5, 0.0, 1.0)
	_rain.emitting = rain > 0.01
	_rain.amount_ratio = rain

	# Kamerawackeln
	var shake := s * s * 0.06 + _jolt * 0.25
	_camera.h_offset = (sin(_t * 13.0) + sin(_t * 7.3)) * shake
	_camera.v_offset = (sin(_t * 11.0 + 2.0) + sin(_t * 5.7)) * shake

	if _flash_rect:
		_flash_rect.color.a = _flash * 0.55
	_fill_audio(delta)


# ---------- für die Methoden-Spur der Zeitleiste ----------

## Blendet einen Text in der Bildmitte ein ("" blendet aus).
func title(text: String) -> void:
	var tween := create_tween()
	if text == "":
		tween.tween_property(_title, "modulate:a", 0.0, 1.0)
	else:
		_title.text = text
		_title.modulate.a = 0.0
		tween.tween_property(_title, "modulate:a", 1.0, 1.2)


## Schwarzblende: alpha 1 = schwarz.
func fade(alpha: float, duration: float) -> void:
	create_tween().tween_property(_fade, "color:a", alpha, duration)


func lightning() -> void:
	_flash = 1.0
	_thunder_delay = randf_range(0.15, 0.5)


## Das Schiff läuft aufs Riff.
func crash() -> void:
	_jolt = 1.0
	lightning()
	_thunder_delay = 0.0


## Der Held wird über Bord gespült.
func hero_overboard() -> void:
	var hero := _ship_hero
	var start := hero.global_position
	hero.reparent(self)
	_play_hero(hero, &"Fall3", false)
	var side := _ship.global_basis.z.normalized()
	var tween := create_tween()
	tween.tween_property(hero, "global_position", start + side * 2.5 + Vector3.UP * 1.5, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(hero, "global_position", start + side * 5.0 + Vector3.DOWN * (start.y + 4.0), 1.1) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(hero.hide)


## Die Karte fliegt davon.
func map_fly() -> void:
	var start := _map.global_position
	_map.reparent(self)
	var tween := create_tween().set_parallel()
	tween.tween_property(_map, "global_position", start + Vector3(-9.0, 14.0, 10.0), 3.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_map, "rotation", _map.rotation + Vector3(5.0, 8.0, 3.0), 3.0)
	tween.chain().tween_callback(_map.hide)


## Schnitt zum Strand (während der Schwarzblende).
func to_beach() -> void:
	_on_beach = true
	_ship.visible = false
	_reef.visible = false
	_beach.visible = true
	_map.visible = false
	_crew.visible = false


func birds(on: bool) -> void:
	_birds = on


## Der Held steht am Strand auf (Umfallen rückwärts abgespielt).
func stand_up() -> void:
	var player := _hero_player(_beach_hero)
	player.play_backwards(&"Knock_Down")
	await player.animation_finished
	_play_hero(_beach_hero, &"Idle_9", true)


# ---------- Held ----------

func _hero_player(hero: Node) -> AnimationPlayer:
	return hero.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _play_hero(hero: Node, anim: StringName, loop: bool) -> void:
	var player := _hero_player(hero)
	if player == null or not player.has_animation(anim):
		return
	if loop:
		player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	player.play(anim, 0.3)


## Liegend am Ende der Umfall-Animation anhalten.
func _lie_down(hero: Node) -> void:
	var player := _hero_player(hero)
	if player == null or not player.has_animation(&"Knock_Down"):
		return
	player.play(&"Knock_Down")
	player.seek(player.get_animation(&"Knock_Down").length, true)
	player.pause()


# ---------- Ende ----------

func _go_next() -> void:
	if _leaving:
		return
	_leaving = true
	_anim.pause()
	GameState.set_flag("prolog_seen")
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.5)
	await tween.finished
	var hud := GameState.get_node_or_null("HUD") as CanvasLayer
	if hud:
		hud.visible = _hud_was_visible
	if not Music.playing:
		Music.play()
	get_tree().change_scene_to_file(NEXT_SCENE)


# ---------- Oberfläche ----------

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 20
	add_child(_ui)

	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(0.9, 0.93, 1.0, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_flash_rect)

	_title = Label.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 52)
	_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.65))
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 12)
	_title.modulate.a = 0.0
	_ui.add_child(_title)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color.BLACK   # die Zeitleiste blendet am Anfang auf
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)

	var skip := Label.new()
	skip.text = "%s: überspringen" % GameState.action_label("jump")
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skip.offset_right = -24.0
	skip.offset_bottom = -18.0
	skip.add_theme_font_size_override("font_size", 18)
	skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	skip.add_theme_color_override("font_outline_color", Color.BLACK)
	skip.add_theme_constant_override("outline_size", 6)
	_ui.add_child(skip)


# ---------- Geräusche: Meer, Regen, Donner, Vögel ----------

func _build_audio() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.2
	var player := AudioStreamPlayer.new()
	player.stream = gen
	player.bus = &"Sounds"
	player.volume_db = -4.0
	add_child(player)
	player.play()
	_playback = player.get_stream_playback() as AudioStreamGeneratorPlayback


func _fill_audio(delta: float) -> void:
	if _playback == null:
		return
	if _thunder_delay >= 0.0:
		_thunder_delay -= delta
		if _thunder_delay < 0.0:
			_thunder = 1.0
	var frames := _playback.get_frames_available()
	var s := storm
	var hiss_amp := clampf((s - 0.25) / 0.5, 0.0, 1.0) * 0.35 * sea_volume
	var sea_amp := lerpf(0.9, 2.2, s) * sea_volume
	var dt := 1.0 / MIX_RATE
	for i in frames:
		var white := randf() * 2.0 - 1.0
		# Regen: helles Rauschen
		_lp_hiss += (white - _lp_hiss) * 0.45
		# Brandung: dunkles Rauschen, das in langsamen Wellen an- und abschwillt
		_lp_sea += (white - _lp_sea) * 0.03
		_lp_sea2 += (_lp_sea - _lp_sea2) * 0.1
		_wave_phase += dt * TAU / lerpf(6.0, 3.0, s)
		var swell := 0.35 + 0.65 * pow(0.5 + 0.5 * sin(_wave_phase), 2.0)
		var sample := _lp_hiss * hiss_amp + _lp_sea2 * sea_amp * swell
		# Donner: tiefes Grollen mit langem Ausklingen
		if _thunder > 0.001:
			_lp_thunder += (white - _lp_thunder) * 0.012
			sample += _lp_thunder * _thunder * 9.0
			_thunder *= 0.99985
		# Vögel: kurze, aufsteigende Pfiffe
		if _birds:
			_chirp_wait -= dt
			if _chirp_wait <= 0.0:
				_chirp_time = 0.0
				_chirp_base = randf_range(2200.0, 3600.0)
				_chirp_wait = randf_range(0.12, 1.6)
			if _chirp_time >= 0.0:
				_chirp_time += dt
				if _chirp_time > 0.09:
					_chirp_time = -1.0
				else:
					_chirp_phase += TAU * (_chirp_base + _chirp_time * 9000.0) * dt
					sample += sin(_chirp_phase) * sin(PI * _chirp_time / 0.09) * 0.08
		sample = clampf(sample, -1.0, 1.0)
		_playback.push_frame(Vector2(sample, sample))
