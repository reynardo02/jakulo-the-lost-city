extends Node
## Die Schlinge (Autoload "Sling"), das Item aus Level 3. Man zielt selbst:
##
## - Aktion "sling" (F, linke Maustaste, R2) GEDRÜCKT HALTEN: Zielmodus. Die Kamera zoomt etwas
##   heran, in der Bildmitte erscheint ein Fadenkreuz. Mit Maus bzw. rechtem Stick zielen.
##   Liegt ein Ziel unter dem Fadenkreuz, wird es golden.
## - LOSLASSEN: Der Stein fliegt in Richtung Fadenkreuz. Trifft er ein Ziel, wird dort
##   sling_hit() gerufen; sonst prallt er dort ab, wo er auf etwas trifft.
##
## Ziele sind Knoten in der Gruppe "sling_target". Jedes Ziel in Reichweite trägt einen
## leuchtenden Ring, damit man sieht, worauf man schießen kann. Ein Treffer zählt, wenn der
## Zielstrahl näher als der Trefferradius am Zielpunkt vorbeigeht (großzügig, damit man gut trifft).
##
## Ein Ziel braucht nur:
##   func sling_hit() -> void                 # wird beim Treffer gerufen
## und optional:
##   func can_be_hit() -> bool                # false = gerade kein gültiges Ziel
##   func get_sling_point() -> Vector3        # Zielpunkt (sonst global_position)
##   func get_sling_radius() -> float         # Trefferradius in m (sonst DEFAULT_RADIUS)
## Beispiele: scripts/sling_rope_log.gd, sling_trigger.gd, scared_animal.gd, wasp_nest.gd und
## die Krokodile (betäubt).

const ITEM := "sling"
const GROUP := "sling_target"
const RANGE := 28.0          ## m, maximale Entfernung vom Spieler zum Ziel
const DEFAULT_RADIUS := 1.0  ## m, so weit darf der Zielstrahl am Zielpunkt vorbeigehen
const COOLDOWN := 0.35       ## s zwischen zwei Schüssen
const STONE_SPEED := 32.0    ## m/s
const AIM_FOV_FACTOR := 0.75 ## Zoom im Zielmodus
const HIT_SOUND := "res://assets/music/sounds/tap.wav"

var is_aiming := false

var _cooldown := 0.0
var _sound: AudioStreamPlayer
var _pulse := 0.0
var _markers := {}           # Ziel -> Sprite3D (Ring)
var _aim_target: Node3D      # Ziel unter dem Fadenkreuz (oder null)
var _camera: Camera3D
var _camera_fov := 0.0
var _fov_tween: Tween
var _ui: CanvasLayer
var _crosshair: Control
var _ring_texture: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_sound = AudioStreamPlayer.new()
	_sound.stream = load(HIT_SOUND)
	_sound.bus = &"Sounds"
	add_child(_sound)
	_ring_texture = _make_ring_texture()
	_build_crosshair()


func _process(delta: float) -> void:
	_cooldown -= delta
	_pulse += delta
	var player := _player()
	var usable := player != null and GameState.has_item(ITEM) and player.is_physics_processing()
	_update_markers(player if usable else null)
	if not usable:
		_stop_aiming()
		return
	var held := Input.is_action_pressed("sling")
	if held and not is_aiming and _cooldown <= 0.0:
		_start_aiming()
	elif not held and is_aiming:
		_stop_aiming()
		_shoot(player)
	if is_aiming:
		_aim_target = _target_under_crosshair(player)
		_crosshair.modulate = Color(1.0, 0.8, 0.2) if _aim_target else Color(1, 1, 1, 0.85)
		_crosshair.scale = Vector2.ONE * (1.25 if _aim_target else 1.0)


# ---------- Zielmodus ----------

func _start_aiming() -> void:
	is_aiming = true
	GameState.show_message("")   # Hinweise in der Bildmitte würden das Fadenkreuz verdecken
	_camera = get_viewport().get_camera_3d()
	_ui.visible = true
	if _camera:
		_camera_fov = _camera.fov
		_tween_fov(_camera_fov * AIM_FOV_FACTOR)


func _stop_aiming() -> void:
	if not is_aiming:
		return
	is_aiming = false
	_ui.visible = false
	if is_instance_valid(_camera):
		_tween_fov(_camera_fov)


func _tween_fov(fov: float) -> void:
	if _fov_tween:
		_fov_tween.kill()
	_fov_tween = create_tween()
	_fov_tween.tween_property(_camera, "fov", fov, 0.15)


## Zielstrahl: von der Kamera durch die Bildmitte.
func _aim_ray() -> Array:
	var cam := get_viewport().get_camera_3d()
	var center := get_viewport().get_visible_rect().size * 0.5
	return [cam.project_ray_origin(center), cam.project_ray_normal(center)]


func _target_under_crosshair(player: Node3D) -> Node3D:
	if get_viewport().get_camera_3d() == null:
		return null
	var ray := _aim_ray()
	var origin: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	var best: Node3D = null
	var best_t := INF
	for target in _valid_targets(player):
		var point := _aim_point(target)
		var t := (point - origin).dot(dir)
		if t <= 0.0 or t >= best_t:
			continue
		var miss := (origin + dir * t).distance_to(point)
		if miss <= _radius(target) and _line_of_sight(player, origin, point, target):
			best = target
			best_t = t
	return best


# ---------- Schuss ----------

func _shoot(player: Node3D) -> void:
	if _cooldown > 0.0 or get_viewport().get_camera_3d() == null:
		return
	_cooldown = COOLDOWN
	var target := _target_under_crosshair(player)
	var to: Vector3
	if target:
		to = _aim_point(target)
	else:
		# daneben: der Stein fliegt bis zum ersten Hindernis oder bis zur Reichweite
		var ray := _aim_ray()
		var origin: Vector3 = ray[0]
		var dir: Vector3 = ray[1]
		to = origin + dir * (RANGE + 6.0)
		var query := PhysicsRayQueryParameters3D.create(origin, to)
		query.exclude = [(player as CollisionObject3D).get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			to = hit.position
	_launch_stone(player, to, target)


func _launch_stone(player: Node3D, to: Vector3, target: Node3D) -> void:
	var stone := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.33, 0.3)
	mesh.material = mat
	stone.mesh = mesh
	get_tree().current_scene.add_child(stone)

	var from := player.global_position + Vector3.UP * 1.6
	var distance := from.distance_to(to)
	var duration := maxf(distance / STONE_SPEED, 0.1)
	var arc := distance * 0.04
	stone.global_position = from
	var tween := stone.create_tween()
	tween.tween_method(func(s: float) -> void:
		if is_instance_valid(stone):
			stone.global_position = from.lerp(to, s) + Vector3.UP * arc * sin(PI * s), 0.0, 1.0, duration)
	tween.tween_callback(func() -> void:
		stone.queue_free()
		if target and is_instance_valid(target) and (not target.has_method("can_be_hit") or target.can_be_hit()):
			_sound.play()
			target.sling_hit())


# ---------- Ziele ----------

func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func _valid_targets(player: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(GROUP):
		var target := node as Node3D
		if target == null or not target.is_visible_in_tree():
			continue
		if target.has_method("can_be_hit") and not target.can_be_hit():
			continue
		if _aim_point(target).distance_to(player.global_position) > RANGE:
			continue
		result.append(target)
	return result


func _aim_point(target: Node3D) -> Vector3:
	if target.has_method("get_sling_point"):
		return target.get_sling_point()
	return target.global_position


func _radius(target: Node3D) -> float:
	if target.has_method("get_sling_radius"):
		return target.get_sling_radius()
	return DEFAULT_RADIUS


func _line_of_sight(player: Node3D, origin: Vector3, point: Vector3, target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(origin, point)
	query.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	if (hit.position as Vector3).distance_to(point) < _radius(target):
		return true
	var collider := hit.collider as Node
	return collider != null and (collider == target or target.is_ancestor_of(collider))


# ---------- Anzeige ----------

## Ein Ring an jedem Ziel in Reichweite; das Ziel unter dem Fadenkreuz leuchtet stärker.
func _update_markers(player: Node3D) -> void:
	var wanted: Array[Node3D] = _valid_targets(player) if player else ([] as Array[Node3D])
	for target in _markers.keys():
		if not is_instance_valid(target) or not (target in wanted):
			var old: Sprite3D = _markers[target]
			if is_instance_valid(old):
				old.queue_free()
			_markers.erase(target)
	for target in wanted:
		var marker: Sprite3D = _markers.get(target)
		if not is_instance_valid(marker):
			marker = _make_marker()
			get_tree().current_scene.add_child(marker)
			_markers[target] = marker
		var hot := is_aiming and target == _aim_target
		marker.global_position = _aim_point(target)
		marker.modulate = Color(1.0, 0.35, 0.15) if hot else Color(1.0, 0.85, 0.25)
		var size := _radius(target) * (1.0 + 0.1 * sin(_pulse * 5.0)) * (1.3 if hot else 1.0)
		marker.pixel_size = size * 2.0 / 64.0


func _make_ring_texture() -> Texture2D:
	var size := 64
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var r := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var a := clampf(1.0 - absf(r - 28.0) / 3.0, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(image)


func _make_marker() -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = _ring_texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.shaded = false
	sprite.render_priority = 10
	return sprite


## Fadenkreuz in der Bildmitte (nur im Zielmodus sichtbar).
func _build_crosshair() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 12
	_ui.visible = false
	add_child(_ui)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(center)
	_crosshair = Control.new()
	_crosshair.custom_minimum_size = Vector2(48, 48)
	_crosshair.pivot_offset = Vector2(24, 24)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func() -> void:
		var c := Vector2(24, 24)
		_crosshair.draw_arc(c, 14.0, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 4.0)
		_crosshair.draw_arc(c, 14.0, 0.0, TAU, 32, Color.WHITE, 2.0)
		for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			_crosshair.draw_line(c + d * 6.0, c + d * 11.0, Color.WHITE, 2.0)
		_crosshair.draw_circle(c, 2.0, Color.WHITE))
	center.add_child(_crosshair)
