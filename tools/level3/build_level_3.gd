extends SceneTree
## Erzeugt scenes/level_3.tscn: Sumpf und der große Baum (siehe docs/roadmap.md, „Level 3 – Plan
## für Sumpf und den großen Baum“). Danach lässt sich alles normal im Editor bearbeiten; dieses
## Script braucht man nur, um das Level von Grund auf neu zu erzeugen. Aufruf:
##   godot --headless --path . -s res://tools/level3/build_level_3.gd
##
## Aufbau (der Weg führt wie in Level 1 und 2 in -Z):
##   Teil 1, Sumpf (z 6 .. -102, x -8 .. 8, Inseln auf y = 0, Wasser bei y = -0.4):
##     ein schlafender Affe abseits des Wegs, Seerosen, zwei Affen mit einem knackenden Ast
##     dazwischen, ein Schlammloch mit Liane, Checkpoint „l3_sumpf“, Krokodil, Treibholz und
##     Seerose, dann eine ganze Affenbande direkt am Pfad mit Ästen und flachem Wasser.
##     Checkpoint „l3_lichtung“ am Rand der Lichtung.
##   Lichtung (z -102 .. -159, x -22 .. 22): Beim Betreten zeigt eine Cutscene die Wache am
##     Schleusenhebel, danach steigt das Wasser (Checkpoint „l3_flut“).
##   Teil 2, der große Baum (Mitte bei z = TZ):
##     Wurzeln: Schlinge am Baumstumpf, Seil durchschießen, der Stamm fällt als Rampe auf den
##       Wurzelabsatz (y 2, Checkpoint „l3_wurzeln“).
##     Stamm: Plattformen spiralförmig nach oben; eine Plattform hängt am Seil, Affen auf einem
##       Ast werden mit dem Wespennest vertrieben. Astgabel mit Checkpoint „l3_stamm“ (y 8.4),
##       eine Zielscheibe klappt einen Ast als Brücke um. Kronenast mit Checkpoint „l3_krone“.
##     Krone: ein letzter Sprungabschnitt mit festen Plattformen, oben der
##       Hebel, der die Flut stoppt. Danach steht der Spieler am Fuß des Baums beim Dorfbewohner
##       und dem freigespülten Höhleneingang (Portal).
##   Zwei Juwelen liegen auf Seitenästen, deren Brücke erst eine weitere Zielscheibe umklappt.

const OUT := "res://scenes/level_3.tscn"

const WATER_START := -0.4
const TZ := -131.0                 # Mitte des großen Baums (x = 0)
const TRUNK_RADIUS := 2.6
const TRUNK_HEIGHT := 24.0
# Checkpoints mit steigendem Wasser und die Marke knapp unter dem jeweils nächsten Checkpoint
const FLOOD_CHECKPOINTS := ["l3_flut", "l3_wurzeln", "l3_stamm", "l3_krone"]
const FLOOD_LEVELS := [1.5, 7.9, 12.7, 17.5]
const FLOOD_SPEEDS := [0.02, 0.045, 0.045, 0.05]

const GROUND := "res://assets/terrain/ground_straight.glb"
const DRIFTWOOD := "res://assets/deco/driftwood.glb"
const LOG := "res://assets/obstacle/Meshy_AI_Mossy_Fallen_Log_1026200851_texture.glb"
const BRANCH := "res://assets/elements/Meshy_AI_Mossy_Fallen_Branch_1026211759_texture.glb"
# Meshy T2 (Smart Topology), erzeugt mit tools/meshy/gen_l3_t2.sh
# geriggter Affe aus Meshy mit Animationen (tools/level3/extract_monkey_anims.gd)
const MONKEY := "res://assets/level3/monkey/monkey_rigged.glb"
const MONKEY_SCALE := 0.9   # das Rigging ist auf 1 m Größe angelegt
const PLATFORM := "res://assets/level3/platform_t2.glb"
const PLATFORM_HEIGHT := 0.6    # das Modell (Deck auf einer Trommel aus Stämmen) wird auf diese Höhe gestaucht
const JEWEL := "res://assets/level3/jewel_t2.glb"
const WASP_NEST := "res://assets/level3/wasp_nest_t2.glb"
const TARGET := "res://assets/level3/target_t2.glb"
const MANGROVE := "res://assets/level3/mangrove.glb"
const REEDS := "res://assets/level3/reeds.glb"
const CLIFF := "res://assets/level3/cliff.glb"
const ISLAND := "res://scripts/swamp_island.gd"
const RIVER_STONE := "res://assets/deco/river_stone.glb"
const ROOTS := "res://assets/nature/roots.glb"
const PLAYER_SCENE := "res://scenes/player.tscn"

var level: Node3D
var _coins := 0
var _boxes := {}   # Modellpfad -> AABB (gemessen an einer Testinstanz)
var _bark: StandardMaterial3D
var _wood: StandardMaterial3D


func _initialize() -> void:
	_build()


func _build() -> void:
	await process_frame   # Autoloads sind dann da
	level = Node3D.new()
	level.name = "level3"
	# Rinde und Planken aus tools/blender/build_level3_assets.py, triplanar aufgelegt
	_bark = _tiled_material("res://assets/level3/bark.png", Vector3(0.35, 0.25, 0.35), Color(0.62, 0.42, 0.28))
	_wood = _tiled_material("res://assets/level3/wood_planks.png", Vector3(0.5, 0.5, 0.5), Color(0.85, 0.6, 0.4))

	_environment()
	_player()
	_bounds()
	var floating := _node("Node3D", "Schwimmend", level) as Node3D
	_water()
	_swamp(floating)
	_clearing()
	_tree()
	_ending()
	_cutscenes()
	_flow()
	_rain()
	_polish_nodes()

	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("level_3.tscn: ", "gespeichert" if err == OK else "Fehler %d" % err)
	level.free()
	quit()


## Knoten, die tools/build_level_polish.py eingeführt hat (Dressing, Vogelrufe, Flutdetails).
## Hier mit erzeugt, damit ein Neubau von Level 3 sie nicht verliert.
func _polish_nodes() -> void:
	var dressing := "res://scenes/dressing/level_3.tscn"
	if ResourceLoader.exists(dressing):
		_scene(dressing, "LandscapeDetails", level)
	var ambience := _node("Node3D", "JungleAmbience", level)
	ambience.set_script(load("res://scripts/jungle_ambience.gd"))
	ambience.set("quiet", true)
	var flood := _node("Node3D", "FloodDetails", level)
	flood.set_script(load("res://scripts/flood_details.gd"))

# ---------- Hilfen ----------

func _own(node: Node, parent: Node) -> Node:
	parent.add_child(node)
	node.owner = level
	return node


func _node(type_name: String, node_name: String, parent: Node, pos := Vector3.ZERO) -> Node:
	var node: Node = ClassDB.instantiate(type_name)
	node.name = node_name
	if node is Node3D:
		(node as Node3D).position = pos
	return _own(node, parent)


func _scene(path: String, node_name: String, parent: Node, pos := Vector3.ZERO, yaw := 0.0) -> Node3D:
	# GEN_EDIT_STATE_INSTANCE: gespeichert wird nur, was sich gegenüber der Szene ändert
	var node := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	node.name = node_name
	node.position = pos
	node.rotation.y = yaw
	return _own(node, parent) as Node3D


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	return mat


## Material mit gekachelter Textur, die ohne UVs über die Weltkoordinaten aufgelegt wird.
func _tiled_material(path: String, scale: Vector3, tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint   # die gebackenen Bilder sind sehr hell, der Farbton kommt von hier
	mat.albedo_texture = load(path)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = scale
	mat.roughness = 0.9
	return mat


## Umrissbox eines Modells (einmal an einer Testinstanz gemessen)
func _box(path: String) -> AABB:
	if _boxes.has(path):
		return _boxes[path]
	var probe := (load(path) as PackedScene).instantiate() as Node3D
	root.add_child(probe)
	var box := AABB()
	var first := true
	for m in probe.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	probe.free()
	_boxes[path] = box
	return box


## Modell in einem Halter: Unterkante auf dem Halter, mittig in x/z.
## mode: "max" = größte Ausdehnung, "height" = Höhe, "width" = Breite in x.
func _model(path: String, parent: Node, node_name: String, pos: Vector3, size: float,
		mode := "max", yaw := 0.0, strip := false) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = pos
	holder.rotation.y = yaw
	_own(holder, parent)
	if strip:
		holder.set_script(load("res://scripts/strip_collision.gd"))
	var box := _box(path)
	var measure := box.size.y if mode == "height" else (box.size.x if mode == "width" \
		else maxf(box.size.x, maxf(box.size.y, box.size.z)))
	var k := size / maxf(measure, 0.001)
	var model := _scene(path, "Model", holder)
	model.scale = Vector3.ONE * k
	var c := box.get_center()
	model.position = Vector3(-c.x * k, -box.position.y * k, -c.z * k)
	return holder


func _box_body(node_name: String, parent: Node, center: Vector3, size: Vector3,
		material: Material = null, body_type := "StaticBody3D") -> Node3D:
	var body := _node(body_type, node_name, parent, center) as Node3D
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	_own(shape, body)
	if material:
		_box_mesh("Mesh", body, Vector3.ZERO, size, material)
	return body


func _box_mesh(node_name: String, parent: Node, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.position = pos
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	return _own(mesh, parent) as MeshInstance3D


func _area(script_path: String, node_name: String, parent: Node, pos: Vector3, size: Vector3,
		offset := Vector3.ZERO) -> Area3D:
	var area := _node("Area3D", node_name, parent, pos) as Area3D
	area.collision_layer = 0
	area.collision_mask = 2
	if script_path != "":
		area.set_script(load(script_path))
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.position = offset
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	_own(shape, area)
	return area


## Bodenkacheln (4 x 4 m) mit Oberkante bei `top`; xs/zs sind Kachelmitten.
func _tiles(parent: Node, prefix: String, xs: Array, zs: Array, top: float) -> void:
	for z in zs:
		for x in xs:
			_scene(GROUND, "%s_%d_%d" % [prefix, int(x), int(-z)], parent, Vector3(x, top, z))


func _hint(node_name: String, parent: Node, pos: Vector3, text: String, action := "", size := Vector3(16, 3, 2)) -> void:
	var hint := _area("res://scripts/hint_zone.gd", node_name, parent, pos, size, Vector3(0, 1.5, 0))
	hint.set("hint", text)
	hint.set("action", action)


func _note(note_id: String, parent: Node, pos: Vector3) -> void:
	var note := _scene("res://scenes/note_trigger.tscn", "Notiz_" + note_id, parent, pos)
	note.set("note_id", note_id)


func _checkpoint(id: String, parent: Node, pos: Vector3) -> void:
	var cp := _scene("res://scenes/checkpoint.tscn", "Checkpoint_" + id, parent, pos)
	cp.set("checkpoint_id", id)


func _coin(parent: Node, pos: Vector3) -> void:
	_coins += 1
	var coin := _scene("res://scenes/coin.tscn", "Coin%d" % _coins, parent, pos)
	coin.scale = Vector3.ONE * 2.0


## Typisiertes Array für Exporte vom Typ Array[NodePath] (ein untypisiertes wird nicht gespeichert).
func _paths(list: Array) -> Array[NodePath]:
	var typed: Array[NodePath] = []
	for p in list:
		typed.append(p)
	return typed


## Punkt am großen Baum: Winkel θ (Grad, 0 = Südseite zum Spieler hin, 90 = +x), Höhe, Abstand.
func _at(theta_deg: float, y: float, r: float) -> Vector3:
	var t := deg_to_rad(theta_deg)
	return Vector3(r * sin(t), y, TZ + r * cos(t))


## Dünner Zylinder von a nach b (lokal im Elternknoten), z. B. ein Seil.
func _rope(node_name: String, parent: Node, a: Vector3, b: Vector3, radius := 0.05,
		color := Color(0.62, 0.5, 0.32)) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	mesh.material = _material(color)
	var rope := MeshInstance3D.new()
	rope.name = node_name
	rope.mesh = mesh
	rope.position = (a + b) * 0.5
	var up := (b - a).normalized()
	var side := up.cross(Vector3.FORWARD)
	if side.length_squared() < 0.001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	rope.basis = Basis(side, up, side.cross(up))
	return _own(rope, parent) as MeshInstance3D


## Baumstamm-Modell entlang der lokalen -Z-Achse (von 0 bis -length), Oberkante bei y = 0.
func _log_along_z(parent: Node, node_name: String, length: float, thickness: float) -> Node3D:
	var holder := _node("Node3D", node_name, parent) as Node3D
	holder.set_script(load("res://scripts/strip_collision.gd"))
	var box := _box(LOG)
	var model := _scene(LOG, "Log", holder)
	var k_len := length / box.size.x
	var k_th := thickness / box.size.y
	model.rotation.y = PI / 2.0   # Modell-x zeigt dann nach -Z
	model.scale = Vector3(k_len, k_th, k_th)
	var c := box.get_center()
	# nach der Drehung: Modell-x -> -Z, Modell-z -> +X
	model.position = Vector3(-c.z * k_th, -box.end.y * k_th, -length / 2.0 + c.x * k_len)
	return holder


# ---------- Grundgerüst ----------

func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.3, 0.34, 0.38)   # Regenwetter: grau verhangen
	sky_mat.sky_horizon_color = Color(0.48, 0.52, 0.52)
	sky_mat.ground_bottom_color = Color(0.03, 0.05, 0.04)
	sky_mat.ground_horizon_color = Color(0.42, 0.46, 0.44)
	sky_mat.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	# kein SSAO/SSIL/volumetrischer Nebel: gibt es im Mobile-Renderer des Projekts nicht
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.4, 0.48, 0.45)   # Regen: grünlich-grauer Dunst
	env.fog_density = 0.78
	env.fog_sky_affect = 0.3
	env.fog_depth_begin = 9.0
	env.fog_depth_end = 105.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.8
	env.adjustment_contrast = 1.06
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	_own(world, level)

	var sun := DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.rotation = Vector3(-0.9, 0.6, 0.0)
	sun.light_color = Color(0.78, 0.84, 0.9)   # kühles, diffuses Licht unter Regenwolken
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	_own(sun, level)


func _player() -> void:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	player.name = "Player"
	player.position = Vector3(0, 0.3, 3)
	player.rotation.y = PI   # Blick in -Z
	_own(player, level)
	player.set("collision_layer", 3)


## Unsichtbare Wände: schmal im Sumpf, breit um die Lichtung.
func _bounds() -> void:
	var body := _node("StaticBody3D", "Spielgrenze", level) as StaticBody3D
	var walls := {
		"SumpfLinks": [Vector3(-10.5, 15, -46.75), Vector3(1, 60, 111.5)],
		"SumpfRechts": [Vector3(10.5, 15, -46.75), Vector3(1, 60, 111.5)],
		"Hinten": [Vector3(0, 15, 9), Vector3(22, 60, 1)],
		"LichtungLinks": [Vector3(-23.5, 15, -130.75), Vector3(1, 60, 57.5)],
		"LichtungRechts": [Vector3(23.5, 15, -130.75), Vector3(1, 60, 57.5)],
		"LichtungEckeLinks": [Vector3(-17, 15, -102.5), Vector3(13, 60, 1)],
		"LichtungEckeRechts": [Vector3(17, 15, -102.5), Vector3(13, 60, 1)],
		"Vorn": [Vector3(0, 15, -159.5), Vector3(48, 60, 1)],
	}
	for wall_name in walls:
		var shape := CollisionShape3D.new()
		shape.name = wall_name
		shape.position = walls[wall_name][0]
		var box := BoxShape3D.new()
		box.size = walls[wall_name][1]
		shape.shape = box
		_own(shape, body)
	# Sicherheitsnetz tief unter allem
	_area("res://scripts/kill_zone.gd", "KillZoneTief", level, Vector3(0, -12, -76), Vector3(120, 2, 220))


func _water() -> void:
	var water := _node("Node3D", "Wasser", level, Vector3(0, WATER_START, 0)) as Node3D
	water.set_script(load("res://scripts/rising_water.gd"))
	water.set("start_level", WATER_START)
	water.set("checkpoint_ids", PackedStringArray(FLOOD_CHECKPOINTS))
	water.set("stage_levels", PackedFloat32Array(FLOOD_LEVELS))
	water.set("stage_speeds", PackedFloat32Array(FLOOD_SPEEDS))
	water.set("floating_path", NodePath("../Schwimmend"))
	water.set("start_message", "")

	var plane := PlaneMesh.new()
	plane.size = Vector2(110, 210)
	plane.subdivide_width = 40
	plane.subdivide_depth = 80
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/prolog/sea.gdshader")
	mat.set_shader_parameter("calm_color", Color(0.06, 0.15, 0.11))
	mat.set_shader_parameter("wave_height", 0.08)
	mat.set_shader_parameter("roughness", 0.15)
	mat.set_shader_parameter("self_light", 0.12)
	mat.set_shader_parameter("ripple_strength", 0.6)
	var surface := MeshInstance3D.new()
	surface.name = "Surface"
	surface.mesh = plane
	surface.material_override = mat
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.position = Vector3(0, 0, -76)
	_own(surface, water)

	# Wer tiefer als 0,3 m einsinkt, verliert ein Leben
	_area("res://scripts/kill_zone.gd", "KillZone", water, Vector3(0, -0.3 - 2.0, -76), Vector3(110, 4, 210))


# ---------- Teil 1: Sumpf ----------

func _swamp(floating: Node3D) -> void:
	var s := _node("Node3D", "Teil1_Sumpf", level) as Node3D
	s.set_script(load("res://scripts/grass_field.gd"))
	s.set("blades_per_m2", 30.0)
	s.set("blade_height", Vector2(0.16, 0.38))
	s.set("random_seed", 731)

	# Insel A: Start, ein einzelner Affe abseits des Wegs
	_island(s, "InselA", Vector3(0, 0, -2), Vector2(4, 8), Vector4(0.8, 0.8, 0.4, 0.6), 11)
	_island(s, "Inselchen", Vector3(8, 0, -5), Vector2(2, 2), Vector4(0.6, 0.3, 0.6, 0.6), 12)
	_sleeper(s, "Affe1", Vector3(8, 0, -5), -PI / 2.0, 8.5)
	_model(LOG, s, "AffeLiegestamm", Vector3(8.4, 0, -6.6), 3.0, "max", 0.3, true)
	_hint("HinweisAffe", s, Vector3(0, 0, 0), "Psst – ein schlafender Affe.\nGeduckt schleichen: %s", "crouch", Vector3(8, 3, 2))
	_coin(s, Vector3(-2.5, 1.2, -7))

	# Seerosen
	_scene("res://scenes/lily_pad.tscn", "Seerose1", floating, Vector3(0, WATER_START, -12.8))
	_scene("res://scenes/lily_pad.tscn", "Seerose2", floating, Vector3(1.2, WATER_START, -17.3))
	_scene("res://scenes/lily_pad.tscn", "Seerose3", floating, Vector3(-0.4, WATER_START, -21.8))

	# Insel B: zwei Affen, dazwischen ein trockener Ast quer über dem Weg
	_island(s, "InselB", Vector3(0, 0, -33), Vector2(8, 8), Vector4(0.5, 0.5, 0.3, 0.4), 13)
	_sleeper(s, "Affe2", Vector3(-6, 0, -33), PI / 2.0, 8.0)
	_sleeper(s, "Affe3", Vector3(6, 0, -33), -PI / 2.0, 8.0)
	_dry_branch(s, "TrockenerAst1", Vector3(0, 0, -33), 8.4)
	_hint("HinweisAst", s, Vector3(0, 0, -26), "Zwei Affen – und dazwischen ein trockener Ast.\nGeduckt schleichen (%s) und über den Ast springen.", "crouch")
	_coin(s, Vector3(0, 1.2, -38))

	# Schlammloch mit Liane
	_box_mesh("Schlamm", s, Vector3(0, -0.28, -45), Vector3(16, 0.1, 8), _material(Color(0.24, 0.18, 0.1)))
	var vine := _node("Node3D", "Liane", s, Vector3(0, 8.0, -45)) as Node3D
	vine.set_script(load("res://scripts/vine.gd"))
	vine.set("length", 6.5)
	_model(MANGROVE, s, "LianenBaum", Vector3(-7.5, -1.0, -45), 11.0, "height", 0.8)
	_coin(s, Vector3(0, 3.0, -45))

	# Insel C mit Checkpoint
	_island(s, "InselC", Vector3(0, 0, -55), Vector2(4, 6), Vector4(0.7, 0.7, 0.3, 0.3), 14)
	_checkpoint("l3_sumpf", s, Vector3(0, 0, -53))

	# Krokodil, Treibholz, Seerose
	var croc := (load("res://scenes/animals/crocodile_stepping_stone.tscn") as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	croc.name = "Krokodil"
	# gleiche Ausrichtung und Größe wie die Krokodile in Level 1 (liegt quer zum Weg)
	croc.transform = str_to_var("Transform3D(-6.5567065e-08, 0, -1.5, 0, 1.5, 0, 1.5, 0, -6.5567065e-08, 0.5, -0.6, -64)")
	_own(croc, floating)
	_drifting_log(floating, "Treibholz", Vector3(-5, WATER_START, -67.5))
	_note("driftwood", s, Vector3(0, 0, -60))
	_scene("res://scenes/lily_pad.tscn", "Seerose4", floating, Vector3(0, WATER_START, -72))

	# Insel D: die Affenbande direkt am Pfad, mit Ästen und flachem Wasser
	# Das flache Wasser (z -88 bis -90,5) bleibt genau so breit wie vorher: dort keine Ausbuchtung,
	# und die Grundrundung ist von der Rechteckgröße abgezogen.
	_island(s, "InselD1", Vector3(0, 0, -81.85), Vector2(8, 5.85), Vector4(0.5, 0.5, 0.0, 0.4), 15)
	_island(s, "InselD2", Vector3(0, 0, -96.65), Vector2(8, 5.85), Vector4(0.5, 0.5, 0.6, 0.0), 16)
	# kleine Schlammbänke mit Schilf am Rand: nur Kulisse, außer Reichweite des Wegs
	for bank in [[Vector3(-9.2, -0.3, -18), Vector2(0.9, 1.6)], [Vector3(9.4, -0.3, -45.5), Vector2(0.7, 2.2)],
			[Vector3(-9.3, -0.3, -66), Vector2(0.8, 1.4)], [Vector3(9.2, -0.3, -71), Vector2(0.9, 1.2)],
			[Vector3(-9.0, -0.3, -10.5), Vector2(0.6, 0.9)]]:
		_island(s, "Schlammbank%d" % int(-bank[0].z), bank[0], bank[1], Vector4(0.4, 0.4, 0.4, 0.4), int(-bank[0].z), false)
	_hint("HinweisBande", s, Vector3(0, 0, -77), "Eine ganze Affenbande direkt am Weg.\nKein Knacken, kein Platschen – und immer geduckt (%s).", "crouch")
	_sleeper(s, "Affe4", Vector3(-3.5, 0, -80), PI / 2.0, 6.0)
	_sleeper(s, "Affe5", Vector3(3.5, 0, -83.5), -PI / 2.0, 6.0)
	_sleeper(s, "Affe6", Vector3(-3.5, 0, -94), PI / 2.0, 6.0)
	_sleeper(s, "Affe7", Vector3(3.5, 0, -97), -PI / 2.0, 6.0)
	_dry_branch(s, "TrockenerAst2", Vector3(0.3, 0, -81.8), 5.0)
	_dry_branch(s, "TrockenerAst3", Vector3(-0.3, 0, -95.5), 5.0)
	# flaches Wasser quer über den Weg: man steht darin, aber es platscht
	_box_body("FlachwasserGrund", s, Vector3(0, -1.05, -89.25), Vector3(16, 1, 2.5), _material(Color(0.22, 0.17, 0.1)))
	var splash := _area("res://scripts/noise_zone.gd", "Flachwasser", s, Vector3(0, -0.2, -89.25), Vector3(16, 0.8, 2.5))
	splash.set("once", false)
	splash.set("noise_radius", 9.0)
	splash.set("pitch", 1.3)
	_coin(s, Vector3(-6, 1.2, -86))
	_coin(s, Vector3(6, 1.2, -100))
	_checkpoint("l3_lichtung", s, Vector3(0, 0, -102))
	_note("monkey", s, Vector3(0, 0, -26))

	# Kulisse: Mangroven und Schilf an den Rändern, Palmen am Start
	var palm := "res://assets/nature/palm.glb"
	_model(palm, s, "Palme1", Vector3(-3.5, 0, 5), 7.5, "height", 0.4)
	_model("res://assets/nature/tree_large.glb", s, "Baum1", Vector3(3.6, 0, 5.2), 10.0, "height", 0.3)
	_model(palm, s, "Palme2", Vector3(-6.5, 0, -37.5), 7.0, "height", 2.0)
	_model(palm, s, "Palme3", Vector3(6.8, 0, -100.5), 8.0, "height", 3.1)
	_model("res://assets/nature/jungle/monstera.glb", s, "Monstera", Vector3(-3.0, 0, -58.5), 2.0, "height")
	_model("res://assets/nature/bush.glb", s, "Busch1", Vector3(3.2, 0, -50), 1.6, "height")
	for i in 9:
		var side := -1.0 if i % 2 == 0 else 1.0
		_model(MANGROVE, s, "Mangrove%d" % i, Vector3(side * (9.0 + (i % 3)), -1.6, -2.0 - i * 11.0), 8.0, "height", i * 1.3)
	for i in 14:
		var side := -1.0 if i % 2 == 0 else 1.0
		_model(REEDS, s, "Schilf%d" % i, Vector3(side * (5.0 + (i % 3) * 1.4), -0.8, -11.0 - i * 6.0), 1.8, "height", i * 0.9)


## Organische Sumpfinsel (scripts/swamp_island.gd). `half` ist das begehbare Rechteck um
## `center` (wie vorher die Kacheln), `bulge` die erlaubte Ausbuchtung je Seite (-x, +x, -z, +z).
## Am Ufer stehen Schilf, Steine und Wurzeln, aber nie dort, wo der Weg weiterführt (±z-Seiten
## nahe der Mitte). `solid = false`: Schlammbank ohne Gras und ohne Kollision (Kulisse).
func _island(parent: Node, node_name: String, center: Vector3, half: Vector2, bulge: Vector4,
		seed_value: int, solid := true) -> Node3D:
	var island := _node("Node3D", node_name, parent, center) as Node3D
	island.set_script(load(ISLAND))
	island.set("half_size", half)
	island.set("max_bulge", bulge)
	island.set("island_seed", seed_value)
	island.set("solid", solid)
	var data: Array = load(ISLAND).outline(half, bulge, seed_value)
	var points: PackedVector2Array = data[0]
	var normals: PackedVector2Array = data[1]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var deco := _node("Node3D", node_name + "_Ufer", parent, center) as Node3D
	var placed := 0
	for i in points.size():
		var n := normals[i]
		var p := points[i]
		# Wegseiten frei lassen: dort springt der Spieler auf die Insel oder von ihr herunter
		if absf(n.y) > 0.6 and absf(p.x) < half.x * 0.6 + 1.5 and solid:
			continue
		var roll := rng.randf()
		var yaw := atan2(n.x, n.y)
		var at := Vector3(p.x + n.x * 0.3, -0.25, p.y + n.y * 0.3)
		if roll < (0.55 if solid else 0.9):
			if i % 2 == 0:
				_model(REEDS, deco, "Schilf%d" % i, at + Vector3(0, -0.15, 0), rng.randf_range(1.2, 2.1), "height", rng.randf() * TAU, true)
				placed += 1
		elif roll < 0.68:
			_model(RIVER_STONE, deco, "Stein%d" % i, at, rng.randf_range(0.35, 0.7), "max", rng.randf() * TAU, true)
		elif roll < 0.76 and solid:
			_model(ROOTS, deco, "Wurzel%d" % i, Vector3(p.x, -0.45, p.y), rng.randf_range(1.2, 1.8), "max", yaw, true)
		elif roll < 0.8 and solid:
			_model(DRIFTWOOD, deco, "Holz%d" % i, at + Vector3(0, -0.1, 0), rng.randf_range(1.4, 2.2), "max", yaw + PI / 2.0, true)
	return island


## Schlafender Affe; yaw dreht ihn zum Weg hin.
func _sleeper(parent: Node, node_name: String, pos: Vector3, yaw: float, hear: float) -> void:
	var monkey := _node("Node3D", node_name, parent, pos) as Node3D
	monkey.rotation.y = yaw
	monkey.set_script(load("res://scripts/sleeping_monkey.gd"))
	monkey.set("hear_radius", hear)
	_rigged_monkey(monkey, "Model", Vector3.ZERO, 0.0, &"sleep")


## Geriggter Affe in einem Halter mit monkey_animator.gd (spielt `start` beim Start).
func _rigged_monkey(parent: Node, node_name: String, pos: Vector3, yaw: float, start: StringName,
		size := 1.0) -> Node3D:
	var holder := _node("Node3D", node_name, parent, pos) as Node3D
	holder.rotation.y = yaw
	holder.set_script(load("res://scripts/monkey_animator.gd"))
	holder.set("start_animation", start)
	var model := _scene(MONKEY, "Monkey", holder)
	model.scale = Vector3.ONE * MONKEY_SCALE * size
	model.rotation.y = PI   # das Meshy-Modell blickt nach -Z, die Skripte erwarten +Z
	return holder


## Trockener Ast quer über dem Weg (Länge in x): hell gefärbt, damit man ihn sieht.
func _dry_branch(parent: Node, node_name: String, pos: Vector3, length: float) -> void:
	var zone := _area("res://scripts/noise_zone.gd", node_name, parent, pos, Vector3(length, 0.5, 0.7), Vector3(0, 0.25, 0))
	zone.set("message", "Knack!")
	var box := _box(BRANCH)
	var holder := _node("Node3D", "Model", zone) as Node3D
	var model := _scene(BRANCH, "Branch", holder)
	var k := length / box.size.x
	model.scale = Vector3(k, 0.35 / box.size.y * 1.6, 0.6 / box.size.z * 1.4)
	var c := box.get_center()
	model.position = Vector3(-c.x * model.scale.x, -box.position.y * model.scale.y, -c.z * model.scale.z)
	var dry := _material(Color(0.86, 0.76, 0.56))
	dry.emission_enabled = true
	dry.emission = Color(0.35, 0.28, 0.12)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = dry


func _drifting_log(parent: Node, node_name: String, pos: Vector3) -> void:
	var log_body := _box_body(node_name, parent, pos, Vector3(4.0, 0.5, 1.5), null, "AnimatableBody3D")
	log_body.set_script(load("res://scripts/drifting_log.gd"))
	log_body.set("travel", Vector3(10, 0, 0))
	log_body.set("speed", 1.6)
	_model(DRIFTWOOD, log_body, "Model", Vector3(0, -0.4, 0), 4.2, "width", 0.0, true)


# ---------- Lichtung ----------

func _clearing() -> void:
	var s := _node("Node3D", "Lichtung", level) as Node3D
	s.set_script(load("res://scripts/grass_field.gd"))
	s.set("blades_per_m2", 22.0)
	s.set("blade_height", Vector2(0.14, 0.32))
	s.set("random_seed", 732)
	var xs := []
	for i in 11:
		xs.append(-20 + i * 4)
	var zs := []
	for i in 14:
		zs.append(-104.5 - i * 4)
	_tiles(s, "Boden", xs, zs, 0.0)

	_area("", "ClearingTrigger", s, Vector3(0, 0, -105.5), Vector3(20, 6, 1.5), Vector3(0, 3, 0))
	_node("Marker3D", "FlutStart", s, Vector3(0, 0.3, -106.5))

	# Schleuse in der Felswand rechts, davor der Hebel mit der Wache
	var wall := "res://assets/terrain/rock_wall_tall.glb"
	var slot_z := -112.5
	for i in 13:
		var z := -104.8 - i * 4.6
		if absf(z - slot_z) < 3.0:
			continue
		_scene(wall, "FelsRechts%d" % i, s, Vector3(22.6, 0, z), -PI / 2.0)
		_scene(wall, "FelsLinks%d" % i, s, Vector3(-22.6, 0, z), PI / 2.0)
	var stone := _material(Color(0.42, 0.4, 0.36))
	_box_body("SchleusePfeiler1", s, Vector3(22.3, 2.6, slot_z + 2.3), Vector3(1.4, 5.2, 1.0), stone)
	_box_body("SchleusePfeiler2", s, Vector3(22.3, 2.6, slot_z - 2.3), Vector3(1.4, 5.2, 1.0), stone)
	_box_body("SchleuseSturz", s, Vector3(22.3, 5.6, slot_z), Vector3(1.4, 0.8, 5.6), stone)
	_box_body("Schleusentor", s, Vector3(22.0, 1.6, slot_z), Vector3(0.4, 3.4, 3.6), _wood, "AnimatableBody3D")
	var fall := _model("res://assets/deco/waterfall.glb", s, "SchleusenWasser", Vector3(21.0, WATER_START, slot_z), 3.6, "height", -PI / 2.0)
	fall.visible = false

	var lever := _lever(s, "SchleusenHebel", Vector3(19.6, 0, -109.0), 1.0)
	lever.rotation.y = -PI / 2.0
	var guard := _model("res://assets/village/guard.glb", s, "Wache", Vector3(18.0, 0, -107.6), 1.0, "height")
	guard.get_node("Model").scale = Vector3.ONE   # Höhe des geriggten Modells stimmt nur unskaliert
	guard.get_node("Model").position = Vector3.ZERO
	guard.rotation.y = atan2(1.6, -1.4)

	# Kulisse: Bäume und Felsen um die Lichtung
	var trees := ["res://assets/nature/tree_large.glb", "res://assets/nature/palm.glb", "res://assets/nature/tree_medium.glb"]
	for i in 12:
		var z := -108.0 - i * 4.4
		_model(trees[i % 3], s, "BaumLinks%d" % i, Vector3(-19.5 - (i % 2) * 1.2, 0, z), 9.0 + (i % 3) * 2.0, "height", i * 0.7)
		if absf(z - slot_z) > 5.0:
			_model(trees[(i + 1) % 3], s, "BaumRechts%d" % i, Vector3(19.5 + (i % 2) * 1.2, 0, z - 1.5), 9.0 + (i % 2) * 3.0, "height", i * 1.1)
	for i in 9:
		_model(trees[i % 3], s, "BaumHinten%d" % i, Vector3(-18 + i * 4.5, 0, -156.5), 10.0 + (i % 3) * 2.0, "height", i * 0.9)
	for i in 5:
		_model("res://assets/nature/bush.glb", s, "Busch%d" % i, Vector3(-14 + i * 7.0, 0, -108.0 - (i % 2) * 3.0), 1.5, "height", i)
	_model("res://assets/nature/jungle/jungle_bush_dense.glb", s, "BuschDicht1", Vector3(-12, 0, -146), 3.0, "height", 1.0)
	_model("res://assets/nature/jungle/jungle_bush_dense.glb", s, "BuschDicht2", Vector3(13, 0, -142), 3.0, "height", 2.0)


func _lever(parent: Node, node_name: String, pos: Vector3, size: float) -> Node3D:
	var lever := _node("Node3D", node_name, parent, pos) as Node3D
	lever.set_script(load("res://scripts/lever.gd"))
	_model("res://assets/props/lever.glb", lever, "Model", Vector3.ZERO, size, "height", 0.0, true)
	_area("", "Area", lever, Vector3.ZERO, Vector3(3, 2.5, 3), Vector3(0, 1.2, 0))
	return lever


# ---------- Teil 2: der große Baum ----------

func _tree() -> void:
	var s := _node("Node3D", "Teil2_Baum", level) as Node3D

	# Stamm
	var trunk := _node("StaticBody3D", "Stamm", s, Vector3(0, TRUNK_HEIGHT / 2.0, TZ)) as Node3D
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var cyl := CylinderShape3D.new()
	cyl.radius = TRUNK_RADIUS
	cyl.height = TRUNK_HEIGHT
	shape.shape = cyl
	_own(shape, trunk)
	var mesh := CylinderMesh.new()
	mesh.top_radius = TRUNK_RADIUS * 0.85
	mesh.bottom_radius = TRUNK_RADIUS * 1.05
	mesh.height = TRUNK_HEIGHT
	mesh.radial_segments = 18
	mesh.material = _bark
	var trunk_mesh := MeshInstance3D.new()
	trunk_mesh.name = "Mesh"
	trunk_mesh.mesh = mesh
	_own(trunk_mesh, trunk)
	_model("res://assets/nature/jungle/giant_tree.glb", s, "Krone", Vector3(0, 0, TZ), 31.0, "height", 0.4)
	for i in 6:
		var a := i * 60.0 + 20.0
		_model("res://assets/nature/roots.glb", s, "Wurzel%d" % i, _at(a, 0.0, TRUNK_RADIUS + 1.2), 5.0, "max", deg_to_rad(a))
	_note("big_tree", s, Vector3(0, 0, -112))

	_roots_level(s)
	_trunk_level(s)
	_crown_level(s)


## Wurzeln: Schlinge, Seil durchschießen, Stamm fällt als Rampe auf den Wurzelabsatz.
func _roots_level(s: Node3D) -> void:
	_model("res://assets/deco/tree_stump.glb", s, "Baumstumpf", Vector3(2.5, 0, -114.5), 0.6, "height")
	var pickup := _area("res://scripts/item_pickup.gd", "Schlinge", s, Vector3(2.5, 1.0, -114.5), Vector3(1.6, 1.6, 1.6))
	pickup.set("item_id", "sling")
	pickup.set("message", "Die Schlinge!\nZielen: F / R2 gedrückt halten,\nloslassen zum Schießen.")
	_model("res://assets/level3/sling.glb", pickup, "Model", Vector3(0, -0.3, 0), 0.7)
	_note("sling", s, Vector3(2.5, 0, -114.5))
	_hint("HinweisSeil", s, Vector3(0, 0, -116.5), "Ziel 1 von 3: der rote Knoten am Seil.\n%s halten, zielen, loslassen.", "sling", Vector3(10, 3, 2))

	# Wurzelabsatz am Stamm (y 2)
	var ledge := _box_body("Wurzelabsatz", s, Vector3(0, 1.0, TZ + 4.4), Vector3(5, 2, 3.6), _bark)
	_model("res://assets/nature/roots.glb", ledge, "Wurzeln", Vector3(0, 0.95, 0), 6.0, "max")
	_checkpoint("l3_wurzeln", s, Vector3(0, 2.0, TZ + 3.6))

	# Stamm am Seil: fällt nach -Z und liegt dann als Rampe auf dem Absatz
	var length := 6.8
	# Drehpunkt 0,4 m unter dem Boden: Die Oberseite des Stamms beginnt dann ebenerdig
	# und endet liegend auf der Höhe des Absatzes (y 2).
	var tilt := rad_to_deg(acos(2.0 / length))
	var pivot_z := TZ + 5.9 + sin(deg_to_rad(tilt)) * length
	var root_node := _node("Node3D", "SeilStamm", s, Vector3(0, -0.4, pivot_z)) as Node3D
	root_node.set_script(load("res://scripts/sling_rope_log.gd"))
	root_node.set("fallen_angle_deg", -tilt)
	var pivot := _node("AnimatableBody3D", "Pivot", root_node) as Node3D
	var log_shape := CollisionShape3D.new()
	log_shape.name = "Shape"
	log_shape.position = Vector3(0, length / 2.0, 0)
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.3, length, 0.8)
	log_shape.shape = box_shape
	_own(log_shape, pivot)
	# liegender Stamm (Länge in x) wird aufgerichtet: x -> y
	var holder := _node("Node3D", "Model", pivot) as Node3D
	holder.set_script(load("res://scripts/strip_collision.gd"))
	var box := _box(LOG)
	var model := _scene(LOG, "Log", holder)
	var k_len := length / box.size.x
	var k_thick := 0.8 / box.size.y
	model.rotation.z = PI / 2.0
	model.scale = Vector3(k_len, k_thick, k_thick)
	model.position = Vector3(box.size.y * k_thick * 0.5, length / 2.0, -box.get_center().z * k_thick)
	_node("Marker3D", "RopeTop", pivot, Vector3(0, length - 0.6, 0))
	var rope_mesh := _node("MeshInstance3D", "Rope", root_node)
	# roter Knoten in der Seilmitte: das Ziel (verschwindet mit dem Seil)
	var knot := MeshInstance3D.new()
	knot.name = "Knoten"
	var ball := SphereMesh.new()
	ball.radius = 0.35
	ball.height = 0.7
	var knot_mat := _material(Color(0.85, 0.12, 0.08))
	knot_mat.emission_enabled = true
	knot_mat.emission = Color(0.4, 0.05, 0.02)
	ball.material = knot_mat
	knot.mesh = ball
	_own(knot, rope_mesh)
	_node("Marker3D", "Anchor", root_node, Vector3(0, 8.9, TZ + TRUNK_RADIUS - pivot_z))
	_coin(s, Vector3(-2.5, 3.2, TZ + 4.4))


## Stamm: Plattformen spiralförmig von y 2 bis zum Kronenast (y 13.2).
func _trunk_level(s: Node3D) -> void:
	_platform(s, "S1", _at(60, 2.8, 4.6))
	_platform(s, "S2", _at(100, 3.6, 4.4))
	_platform(s, "S3", _at(140, 4.4, 4.4))
	_coin(s, _at(100, 4.8, 4.4))

	_platform(s, "S4", _at(180, 5.2, 4.4))

	_platform(s, "S5", _at(225, 6.0, 4.4))
	_platform(s, "S6", _at(270, 6.8, 5.0))

	# Ast mit Affen von S6 zu S7; das Wespennest darüber vertreibt sie
	_platform(s, "S7", _at(0, 7.6, 5.0))
	var a := _at(270, 6.8, 5.0)
	var b := _at(360, 7.6, 5.0)
	_beam(s, "AffenAst", a, b, 1.4, 1.3)
	var mid := (a + b) * 0.5
	var monkey := _scared_monkey(s, "AffeAufAst", mid, a)
	var nest := _node("Node3D", "Wespennest", s, mid) as Node3D
	nest.set_script(load("res://scripts/wasp_nest.gd"))
	nest.set("scares", NodePath("../" + monkey.name))
	nest.set("fall_distance", 3.6)
	_model(WASP_NEST, nest, "Model", Vector3(0, 4.0, 0), 1.9, "height")
	_branch_stub(s, "NestAst", 315, 11.6, 5.6)

	# Astgabel mit Checkpoint
	var fork := _box_body("Astgabel", s, _at(45, 8.15, 4.9), Vector3(3.4, 0.5, 3.4), _wood)
	fork.rotation.y = deg_to_rad(45)
	_beam(s, "AstgabelStuetze", _at(45, 7.7, TRUNK_RADIUS - 0.2), _at(45, 7.7, 4.0), 0.8, 0.0, false)
	_checkpoint("l3_stamm", s, _at(45, 8.4, 4.9))

	_platform(s, "S8", _at(90, 9.2, 4.4))
	_platform(s, "S9", _at(135, 10.0, 5.0))
	_coin(s, _at(90, 10.4, 4.4))

	# Klappast von S9 zu S10, ausgelöst von einer Zielscheibe am Stamm
	# S10 liegt 1,6 m höher als S9: zu hoch zum Springen, auch mit dem weiten Sprung
	_platform(s, "S10", _at(225, 11.6, 5.0))
	# Der Ast hängt hochgeklappt an S10 und klappt zu S9 herunter; so steht er nicht zwischen
	# S9 und der Zielscheibe, die gleich neben S9 am Stamm hängt.
	_folding_bridge(s, "Klappast", _at(225, 11.6, 5.0), _at(135, 10.0, 5.0), 1.2, 0.6)
	_target_board(s, "Zielscheibe", _at(160, 12.6, TRUNK_RADIUS + 0.15), 160.0, [NodePath("../Klappast")])
	_hint("HinweisScheibe", s, _at(135, 10.0, 5.0), "Ziel 3 von 3: die Zielscheibe am Stamm.\n%s halten, zielen, loslassen.", "sling", Vector3(3, 3, 3))

	_platform(s, "S11", _at(270, 12.0, 4.4))
	_platform(s, "S12", _at(315, 12.4, 4.4))
	_platform(s, "S13", _at(0, 12.8, 4.4))
	_coin(s, _at(315, 13.6, 4.4))

	# Kronenast mit Checkpoint
	var crown_branch := _box_body("Kronenast", s, _at(45, 12.95, 4.9), Vector3(3.4, 0.5, 3.4), _wood)
	crown_branch.rotation.y = deg_to_rad(45)
	_beam(s, "KronenastStuetze", _at(45, 12.5, TRUNK_RADIUS - 0.2), _at(45, 12.5, 4.0), 0.8, 0.0, false)
	_checkpoint("l3_krone", s, _at(45, 13.2, 4.9))

	# Juwel 1: Seitenast hinter S6
	_jewel_branch(s, 1, 270, 6.8, 6.2, 12.6)


## Krone: ein letzter Sprungabschnitt mit festen Plattformen, oben der Hebel.
func _crown_level(s: Node3D) -> void:
	_platform(s, "C1", _at(95, 14.0, 5.2))
	_platform(s, "C2", _at(140, 14.8, 5.6))
	_platform(s, "C2b", _at(185, 15.2, 5.4))
	_platform(s, "C3", _at(230, 15.6, 5.2))
	_platform(s, "C4", _at(275, 16.4, 5.0))
	_platform(s, "C5", _at(320, 17.2, 4.8))
	_coin(s, _at(230, 16.8, 5.2))

	# Spitze mit dem Hebel
	_box_body("Kronenspitze", s, _at(0, 17.75, 4.8), Vector3(4.0, 0.5, 4.0), _wood)
	_beam(s, "SpitzeStuetze", _at(0, 17.3, TRUNK_RADIUS - 0.4), _at(0, 17.3, 3.6), 0.8, 0.0, false)
	var lever := _lever(s, "KronenHebel", _at(0, 18.0, 5.6), 1.4)
	lever.rotation.y = PI / 2.0
	_hint("HinweisHebel", s, _at(320, 17.2, 4.8), "Oben ist der Hebel für die Schleusen!", "", Vector3(3, 3, 3))

	# Juwel 2: Seitenast hinter dem Kronenast
	_jewel_branch(s, 2, 45, 13.2, 6.6, 12.6)


## Holzplattform am Baum: Oberkante bei pos.y, Stütze bis zum Stamm.
func _platform(parent: Node, node_name: String, pos: Vector3, body_type := "StaticBody3D",
		support := true) -> Node3D:
	var body := _node(body_type, node_name, parent, pos) as Node3D
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.75
	cyl.height = 0.4
	shape.shape = cyl
	shape.position.y = -0.2
	_own(shape, body)
	# Modell: 3,6 m breit, flach gestaucht, Oberkante (Deck) bei y = 0
	var box := _box(PLATFORM)
	var k := 3.6 / box.size.x
	var ky := PLATFORM_HEIGHT / box.size.y
	var holder := _node("Node3D", "Model", body) as Node3D
	holder.rotation.y = (pos.x + pos.z) * 0.37
	holder.set_script(load("res://scripts/strip_collision.gd"))
	var model := _scene(PLATFORM, "Platform", holder)
	model.scale = Vector3(k, ky, k)
	var c := box.get_center()
	model.position = Vector3(-c.x * k, -box.end.y * ky, -c.z * k)
	if support:
		# Stütze vom Stamm zur Plattform (nur Optik, bewegt sich mit)
		var center := Vector3(0, pos.y, TZ)
		var flat := Vector3(pos.x, pos.y, pos.z) - center
		var inward := -flat.normalized() * (flat.length() - TRUNK_RADIUS + 0.3)
		_rope("Stuetze", body, Vector3(0, -0.45, 0), inward + Vector3(0, -1.0, 0), 0.18, Color(0.33, 0.24, 0.16))
	return body


## Gerader Steg (Box) von a nach b, Oberkante bei der Höhe der Endpunkte.
func _beam(parent: Node, node_name: String, a: Vector3, b: Vector3, width: float, trim: float,
		collide := true) -> Node3D:
	var dir := (b - a).normalized()
	var length := a.distance_to(b) - trim
	var basis := Basis.looking_at(dir, Vector3.UP)
	var center := (a + b) * 0.5 - basis.y * 0.2
	var body: Node3D
	if collide:
		body = _box_body(node_name, parent, center, Vector3(width, 0.4, length), _wood)
	else:
		body = _box_mesh(node_name, parent, center, Vector3(width, 0.4, length), _bark)
	body.basis = basis
	return body


## Kurzer Ast aus dem Stamm (nur Optik), z. B. als Halt für ein Seil.
func _branch_stub(parent: Node, node_name: String, theta: float, y: float, r: float) -> void:
	_beam(parent, node_name, _at(theta, y, TRUNK_RADIUS - 0.3), _at(theta, y, r), 0.5, 0.0, false)


## Affe auf dem Ast, der den Weg sperrt (scared_animal.gd). Blickt zu `look`.
func _scared_monkey(parent: Node, node_name: String, pos: Vector3, look: Vector3) -> Node3D:
	var animal := _node("Node3D", node_name, parent, pos) as Node3D
	animal.set_script(load("res://scripts/scared_animal.gd"))
	animal.set("direct_hit", false)
	animal.set("note_id", "monkey")
	animal.set("blocked_hint", "Ziel 2 von 3: das Wespennest über den Affen.\n{sling} halten, zielen, loslassen.")
	animal.set("flee_offset", Vector3(0, 8, 6))
	var to := look - pos
	animal.rotation.y = atan2(to.x, to.z)
	animal.set("hop_height", 0.0)   # die Idle-Animation bewegt sie schon
	_rigged_monkey(animal, "Model", Vector3.ZERO, 0.0, &"idle")
	_rigged_monkey(animal, "Model2", Vector3(0.6, 0, -1.0), 0.6, &"idle", 0.8)
	_box_body("Blocker", animal, Vector3(0, 2, 0), Vector3(4.5, 4, 0.8))
	_area("", "Sight", animal, Vector3.ZERO, Vector3(4, 3, 7), Vector3(0, 1.5, 4.5))
	return animal


## Ast, der hochgeklappt am Ende von `a` hängt und auf activate() als Brücke Richtung `b`
## herunterklappt. `start_gap`: Abstand des Gelenks von a, `overlap`: so weit ragt er über b.
func _folding_bridge(parent: Node, node_name: String, a: Vector3, b: Vector3, start_gap: float,
		overlap: float, folded := true) -> Node3D:
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var dir := flat.normalized()
	var hinge := a + dir * start_gap
	var run := flat.length() - start_gap - 1.75 + overlap
	var rise := b.y - a.y
	var length := sqrt(run * run + rise * rise)
	var pitch := atan2(rise, run)
	var body: Node3D
	if folded:
		body = _node("AnimatableBody3D", node_name, parent, hinge + Vector3(0, -0.2, 0)) as Node3D
		body.set_script(load("res://scripts/moving_part.gd"))
		body.rotation = Vector3(PI / 2.0, atan2(-dir.x, -dir.z), 0)
		body.set("end_rotation_deg", Vector3(rad_to_deg(pitch) - 90.0, 0, 0))
		body.set("duration", 0.9)
	else:
		# liegt von Anfang an als Brücke
		body = _node("StaticBody3D", node_name, parent, hinge + Vector3(0, -0.2, 0)) as Node3D
		body.rotation = Vector3(pitch, atan2(-dir.x, -dir.z), 0)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.position = Vector3(0, 0, -length / 2.0)
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 0.4, length)
	shape.shape = box
	_own(shape, body)
	var log := _log_along_z(body, "Model", length, 0.6)
	log.position.y = 0.2
	return body


## Zielscheibe (Ziel der Schlinge), Vorderseite zeigt in Richtung θ vom Stamm weg.
func _target_board(parent: Node, node_name: String, pos: Vector3, facing_deg: float,
		targets: Array) -> Node3D:
	var trigger := _node("Node3D", node_name, parent, pos) as Node3D
	trigger.set_script(load("res://scripts/sling_trigger.gd"))
	trigger.set("style", "board")
	trigger.set("targets", _paths(targets))
	trigger.rotation.y = deg_to_rad(facing_deg)
	# Strohzielscheibe auf Holzbrett (Meshy), etwa 2,2 m breit, mittig auf dem Knoten
	var box := _box(TARGET)
	var k := 2.2 / box.size.x
	var holder := _node("Node3D", "Model", trigger) as Node3D
	var model := _scene(TARGET, "Board", holder)
	model.scale = Vector3.ONE * k
	model.position = -box.get_center() * k
	return trigger


## Seitenast mit Juwel: Plattform etwas abseits und höher, ein Ast als Steg vom Weg bei
## (θ, y, r_from) dorthin. Ein kleiner Umweg, aber ohne Ziel für die Schlinge.
func _jewel_branch(parent: Node, index: int, theta: float, y: float, r_from: float, r_to: float) -> void:
	var far := _at(theta, y + 1.0, r_to)
	_platform(parent, "JuwelAst%d" % index, far, "StaticBody3D", false)
	_rope("JuwelAstStuetze%d" % index, parent, far + Vector3(0, -0.4, 0), _at(theta, y - 3.0, TRUNK_RADIUS), 0.2, Color(0.33, 0.24, 0.16))
	var bridge_name := "JuwelBruecke%d" % index
	# Gelenk bei r_from: Startpunkt 1,2 m weiter innen, Abstand 1,2 m
	_folding_bridge(parent, bridge_name, _at(theta, y, r_from - 1.2), far, 1.2, 0.5, false)
	var gem := _area("res://scripts/item_pickup.gd", "Juwel%d" % index, parent, far + Vector3(0, 1.0, 0), Vector3(1.4, 1.6, 1.4))
	gem.set("item_id", "jewel")
	gem.set("once", false)
	gem.set("pickup_flag", "jewel_l3_%d" % index)
	gem.set("message", "Ein Juwel!")
	_model(JEWEL, gem, "Model", Vector3(0, -0.3, 0), 0.7)
	# rotes Leuchten, damit das Juwel auch im Schatten der Krone auffällt
	var glow := _node("OmniLight3D", "Glow", gem, Vector3(0, 0.3, 0)) as OmniLight3D
	glow.light_color = Color(1.0, 0.2, 0.25)
	glow.light_energy = 1.6
	glow.omni_range = 2.5


# ---------- Abschluss: Dorfbewohner und Höhleneingang ----------

func _ending() -> void:
	var s := _node("Node3D", "Abschluss", level) as Node3D
	var cave_z := TZ - TRUNK_RADIUS - 0.4
	var portal := _scene("res://scenes/ruins/magic_portal.tscn", "MagicPortal", s, Vector3(0, 0, cave_z), PI)
	portal.scale = Vector3(1.2, 1.8, 1.0)
	portal.set("required_flag", "l3_flood_stopped")
	portal.set("locked_hint", "Hier geht es nicht weiter – noch nicht.")
	# Felsbogen um den Eingang
	_model(CLIFF, s, "HoehleLinks", Vector3(-2.4, 0, cave_z - 0.3), 4.6, "height", 0.3)
	_model(CLIFF, s, "HoehleRechts", Vector3(2.4, 0, cave_z - 0.3), 4.4, "height", 2.1)
	_model(CLIFF, s, "HoehleOben", Vector3(0, 3.6, cave_z - 0.1), 2.6, "height", 1.2)
	_box_body("HoehleVerschuettet", s, Vector3(0, 1.6, cave_z - 0.9), Vector3(4.2, 3.2, 1.2), _material(Color(0.26, 0.2, 0.12)))

	var villager := _model("res://assets/village/villager.glb", s, "Dorfbewohner", Vector3(-2.8, 0, TZ - 6.5), 1.0, "height")
	villager.get_node("Model").scale = Vector3.ONE * 0.95
	villager.get_node("Model").position = Vector3.ZERO
	villager.rotation.y = atan2(2.8, -4.5)
	_node("Marker3D", "EndeStart", s, Vector3(0, 0.3, TZ - 11.0))


# ---------- Wetter ----------

## Regen über der Kamera (scripts/rain.gd) mit Regengeräusch und gelegentlichem Donner.
func _rain() -> void:
	var rain := GPUParticles3D.new()
	rain.name = "Regen"
	rain.set_script(load("res://scripts/rain.gd"))
	rain.amount = 3000
	rain.lifetime = 0.9
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 1, 16)
	pm.direction = Vector3(0.1, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 20.0
	pm.initial_velocity_max = 24.0
	pm.gravity = Vector3(0, -6, 0)
	rain.process_material = pm
	var drop := BoxMesh.new()
	drop.size = Vector3(0.015, 0.6, 0.015)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.albedo_color = Color(0.75, 0.8, 0.88, 0.3)
	drop.material = drop_mat
	rain.draw_pass_1 = drop
	_own(rain, level)
	rain.set("flash_light", NodePath("../DirectionalLight3D"))


# ---------- Cutscenes ----------

func _cutscenes() -> void:
	_cutscene("FlutCutscene", 13.2, [
		[0.0, Vector3(0, 2.6, -98), Vector3(0, 9, TZ)],
		[2.98, Vector3(0, 3.4, -103), Vector3(0, 12, TZ)],
		[3.0, Vector3(12.8, 2.3, -103.5), Vector3(19.0, 1.3, -108.8)],
		[6.48, Vector3(13.6, 2.7, -104.6), Vector3(19.6, 1.5, -109.6)],
		[6.5, Vector3(13.5, 3.4, -106.0), Vector3(21.5, 1.4, -112.5)],
		[9.48, Vector3(12.6, 3.9, -107.4), Vector3(21.5, 1.2, -112.5)],
		[9.5, Vector3(6.5, 2.6, -108.5), Vector3(2.0, 0.8, -116.0)],
		[13.2, Vector3(5.2, 2.3, -110.0), Vector3(1.5, 1.2, -117.0)],
	], [
		[0.4, "say", ["", "Mitten auf der Lichtung: der große Baum."]],
		[3.2, "say", ["Wache", "Bis hierher und nicht weiter, Fremder!"]],
		[6.6, "say", ["", "Die Schleuse öffnet sich – Wasser strömt auf die Lichtung!"]],
		[9.6, "say", ["", "Am Fuß des Baums liegt etwas …"]],
		[13.0, "clear_text", []],
	], [
		[3.8, "pull_sluice_lever", []],
		[6.7, "open_sluice", []],
		[7.6, "guard_leave", []],
	])
	_cutscene("EndeCutscene", 13.6, [
		[0.0, _at(0, 22.0, 9.0), Vector3(0, 0, -110)],
		[3.98, _at(0, 23.0, 10.0), Vector3(0, -1, -108)],
		[4.0, Vector3(4.6, 2.2, TZ - 16.0), Vector3(-1.0, 1.4, TZ - 4.5)],
		[13.6, Vector3(3.6, 1.9, TZ - 14.0), Vector3(-1.2, 1.5, TZ - 4.5)],
	], [
		[0.3, "say", ["", "Die Schleusen schließen sich – das Wasser fließt ab."]],
		[3.9, "clear_text", []],
		[13.4, "clear_text", []],
	], [
		[4.0, "show_ending", []],
		[4.4, "villager_say", [0]],
		[7.4, "villager_say", [1]],
		[10.4, "villager_say", [2]],
	])


## Cutscene-Knoten (scripts/cutscene.gd) mit Kamera und Zeitleiste.
## shots: [Zeit, Kameraposition, Blickpunkt]; own: Methoden am Cutscene-Knoten;
## flow: Methoden am Knoten "Ablauf". Alles in Weltkoordinaten.
func _cutscene(node_name: String, length: float, shots: Array, own: Array, flow: Array) -> void:
	var cutscene := _node("Node3D", node_name, level) as Node3D
	cutscene.set_script(load("res://scripts/cutscene.gd"))
	var camera := _node("Camera3D", "Camera", cutscene) as Camera3D
	camera.fov = 55.0

	var anim := Animation.new()
	anim.length = length
	var pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pos, NodePath("Camera:position"))
	var rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot, NodePath("Camera:quaternion"))
	for shot in shots:
		var eye: Vector3 = shot[1]
		anim.track_insert_key(pos, shot[0], eye)
		anim.track_insert_key(rot, shot[0], Transform3D().looking_at(shot[2] - eye, Vector3.UP).basis.get_rotation_quaternion())
	var own_track := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(own_track, NodePath("."))
	for key in own:
		anim.track_insert_key(own_track, key[0], {"method": StringName(key[1]), "args": key[2]})
	var flow_track := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(flow_track, NodePath("../Ablauf"))
	for key in flow:
		anim.track_insert_key(flow_track, key[0], {"method": StringName(key[1]), "args": key[2]})

	var library := AnimationLibrary.new()
	library.add_animation(&"cutscene", anim)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library(&"", library)
	_own(player, cutscene)


func _flow() -> void:
	var flow := _node("Node", "Ablauf", level)
	flow.set_script(load("res://scripts/level_3_flow.gd"))
	var paths := {
		"water": "../Wasser",
		"clearing_trigger": "../Lichtung/ClearingTrigger",
		"flood_cutscene": "../FlutCutscene",
		"end_cutscene": "../EndeCutscene",
		"guard": "../Lichtung/Wache",
		"sluice_lever": "../Lichtung/SchleusenHebel",
		"sluice_gate": "../Lichtung/Schleusentor",
		"sluice_water": "../Lichtung/SchleusenWasser",
		"crown_lever": "../Teil2_Baum/KronenHebel",
		"villager": "../Abschluss/Dorfbewohner",
		"cave_block": "../Abschluss/HoehleVerschuettet",
		"flood_spawn": "../Lichtung/FlutStart",
		"end_spawn": "../Abschluss/EndeStart",
	}
	for key in paths:
		flow.set(key, NodePath(paths[key]))
