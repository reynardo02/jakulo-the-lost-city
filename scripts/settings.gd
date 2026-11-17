extends Node
## Spieleinstellungen (Autoload "GameSettings"): Grafikstufe, Lautstärken, Vollbild.
## Gespeichert in user://settings.cfg und beim Start sofort angewendet.
##
## Grafik "Hoch" = so, wie die Level gebaut sind. "Niedrig" schaltet die teuren Effekte ab:
## volumetrischer Nebel, SSAO, SSIL und Bildschirmspiegelungen, dazu kleinere und härtere Schatten,
## kürzere Schattenreichweite, eine niedrigere 3D-Auflösung mit FSR-Hochskalierung, gröbere LODs,
## halb so viel Gras mit kürzerer Sichtweite und weniger Regentropfen.
## Umgebungen, Lichter und Partikel neu geladener Szenen werden automatisch angepasst.
## Die Grasdichte wirkt erst beim nächsten Levelstart, alles andere sofort.

signal changed

const PATH := "user://settings.cfg"
const QUALITY_HIGH := "high"
const QUALITY_LOW := "low"

var quality := QUALITY_HIGH
var music_volume := 1.0    # 0 .. 1, relativ zur Abmischung im Bus-Layout
var sound_volume := 1.0
var fullscreen := true

var _bus_base_db := {}     # Bus -> Grundpegel aus default_bus_layout.tres
var _base_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_base_scale = float(ProjectSettings.get_setting("rendering/scaling_3d/scale", 1.0))
	for bus in ["Music", "Sounds"]:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			_bus_base_db[bus] = AudioServer.get_bus_volume_db(index)
	fullscreen = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	_load()
	get_tree().node_added.connect(_on_node_added)
	apply_all()


func is_low() -> bool:
	return quality == QUALITY_LOW


## Anteil des Grases gegenüber "Hoch" (für grass_field.gd).
func grass_factor() -> float:
	return 0.5 if is_low() else 1.0


func set_quality(value: String) -> void:
	quality = QUALITY_LOW if value == QUALITY_LOW else QUALITY_HIGH
	_save()
	apply_all()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	_save()


func set_sound_volume(value: float) -> void:
	sound_volume = clampf(value, 0.0, 1.0)
	_apply_audio()
	_save()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_window()
	_save()


func apply_all() -> void:
	_apply_audio()
	_apply_window()
	_apply_rendering()
	var root := get_tree().root
	for node in root.find_children("*", "WorldEnvironment", true, false):
		_apply_environment((node as WorldEnvironment).environment)
	for node in root.find_children("*", "DirectionalLight3D", true, false):
		_apply_sun(node as DirectionalLight3D)
	for node in get_tree().get_nodes_in_group("grass_chunks"):
		apply_grass(node as GeometryInstance3D)
	changed.emit()


# ---------- Anwenden ----------

func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		_apply_environment((node as WorldEnvironment).environment)
		# Szenen können ihre Umgebung erst in _ready setzen
		node.ready.connect(func() -> void: _apply_environment((node as WorldEnvironment).environment), CONNECT_ONE_SHOT)
	elif node is DirectionalLight3D:
		_apply_sun(node as DirectionalLight3D)
	elif node is GPUParticles3D and node.get_script() == preload("res://scripts/rain.gd"):
		_apply_particles(node as GPUParticles3D)


func _apply_rendering() -> void:
	var viewport := get_tree().root
	if is_low():
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		viewport.scaling_3d_scale = minf(_base_scale, 0.58)
		viewport.mesh_lod_threshold = 4.0
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
		RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
	else:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = _base_scale
		viewport.mesh_lod_threshold = 1.0
		RenderingServer.directional_shadow_atlas_set_size(4096, true)
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)


## Die gebauten Werte jeder Umgebung werden beim ersten Mal gemerkt, damit "Hoch" sie zurückholt.
func _apply_environment(env: Environment) -> void:
	if env == null:
		return
	if not env.has_meta("authored"):
		env.set_meta("authored", {
			"volumetric_fog_enabled": env.volumetric_fog_enabled,
			"ssao_enabled": env.ssao_enabled,
			"ssil_enabled": env.ssil_enabled,
			"ssr_enabled": env.ssr_enabled,
			"sdfgi_enabled": env.sdfgi_enabled,
		})
	var authored: Dictionary = env.get_meta("authored")
	for key in authored:
		env.set(key, false if is_low() else authored[key])


func _apply_sun(light: DirectionalLight3D) -> void:
	if not light.has_meta("authored_distance"):
		light.set_meta("authored_distance", light.directional_shadow_max_distance)
	var distance: float = light.get_meta("authored_distance")
	light.directional_shadow_max_distance = minf(distance, 45.0) if is_low() else distance


func _apply_particles(particles: GPUParticles3D) -> void:
	if not particles.has_meta("authored_amount"):
		particles.set_meta("authored_amount", particles.amount)
	var amount: int = particles.get_meta("authored_amount")
	particles.amount = maxi(1, amount / 2) if is_low() else amount


## Sichtweite eines Grasblocks (grass_field.gd ruft das für jeden neuen Block auf).
func apply_grass(chunk: GeometryInstance3D) -> void:
	if not chunk.has_meta("authored_range"):
		chunk.set_meta("authored_range", chunk.visibility_range_end)
	var range_end: float = chunk.get_meta("authored_range")
	chunk.visibility_range_end = range_end * 0.6 if is_low() else range_end


func _apply_audio() -> void:
	for bus in _bus_base_db:
		var index := AudioServer.get_bus_index(bus)
		var volume := music_volume if bus == "Music" else sound_volume
		AudioServer.set_bus_mute(index, volume <= 0.001)
		AudioServer.set_bus_volume_db(index, _bus_base_db[bus] + linear_to_db(maxf(volume, 0.001)))


func _apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var current := DisplayServer.window_get_mode()
	var is_full := current in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if fullscreen and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# ---------- Speichern ----------

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	quality = str(cfg.get_value("graphics", "quality", quality))
	fullscreen = bool(cfg.get_value("graphics", "fullscreen", fullscreen))
	music_volume = float(cfg.get_value("audio", "music", music_volume))
	sound_volume = float(cfg.get_value("audio", "sounds", sound_volume))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "fullscreen", fullscreen)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sounds", sound_volume)
	cfg.save(PATH)
