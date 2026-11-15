extends SceneTree
## Erzeugt scenes/prolog.tscn: den Prolog (Schiffbruch) als Startszene.
## Die Szene lässt sich danach ganz normal im Editor bearbeiten (Zeitleiste im
## AnimationPlayer, Positionen der Requisiten); dieses Script braucht man nur, um sie
## von Grund auf neu zu erzeugen. Das Verhalten steckt in scripts/prolog.gd.
## Aufruf: godot --headless --path . -s res://tools/cutscenes/build_prolog.gd
##
## Aufbau: Das Schiff liegt im Ursprung, Bug in +X. Der Strand für die letzte Einstellung
## liegt am selben Ort und ist bis zur Schwarzblende ausgeblendet; das Meer teilen sich beide.

const OUT := "res://scenes/prolog.tscn"
const HERO_SCENE := "res://assets/character/Meshy_AI_Adventure_Scout_All_Animations(1).glb"
const LENGTH := 52.0

## Drehung des Schiffsmodells, damit der Bug nach +X zeigt
const SHIP_YAW := PI
const SHIP_LENGTH := 16.0
const SHIP_DRAFT := 0.9            # so tief liegt der Rumpf im Wasser
## Deckhöhen (relativ zum Schiff, per Raycast am Modell gemessen):
## Hauptdeck zwischen x = -3 und x = 4, Achterdeck (Heck) zwischen x = -6 und x = -4.
const MAIN_DECK_Y := 0.5
const QUARTER_DECK_Y := 2.95
## Standplatz des Helden an Deck (relativ zum Schiff)
const HERO_DECK := Vector3(-2.5, MAIN_DECK_Y, 0.0)

## Sandhöhe am Strand: steigt von der Wasserlinie (x ≈ -3) zum Dschungel (+X) an
const SAND_SLOPE := 0.07
const SAND_Y0 := 0.2

var scene: Node3D


func _initialize() -> void:
	_build()


func _build() -> void:
	await process_frame   # erst dann gibt es die Autoloads
	scene = Node3D.new()
	scene.name = "Prolog"
	root.add_child(scene)   # für die Größenmessung der Modelle

	_environment()
	_sea()
	_ship()
	_reef()
	_beach()
	_camera()
	_timeline()

	root.remove_child(scene)
	scene.set_script(load("res://scripts/prolog.gd"))
	var packed := PackedScene.new()
	var err := packed.pack(scene)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("prolog.tscn: ", "gespeichert" if err == OK else "Fehler %d" % err)
	scene.free()
	quit()


# ---------- Hilfen ----------

func _own(node: Node, parent: Node) -> Node:
	parent.add_child(node)
	node.owner = scene
	return node


func _instance(path: String, parent: Node, node_name: String) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.name = node_name
	return _own(node, parent) as Node3D


## Umrissbox aller Meshes, im Koordinatensystem von `node`
func _aabb(node: Node3D) -> AABB:
	var inv := node.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (inv * (m as MeshInstance3D).global_transform) * (m as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Skaliert so, dass die größte (oder mit `height` die senkrechte) Ausdehnung `size` ist,
## und setzt den Boden des Modells auf die Unterkante des Elternknotens.
func _fit(node: Node3D, size: float, height := false) -> void:
	node.scale = Vector3.ONE
	var box := _aabb(node)
	var measure := box.size.y if height else maxf(box.size.x, maxf(box.size.y, box.size.z))
	var k := size / maxf(measure, 0.001)
	node.scale = Vector3.ONE * k
	node.position.y -= box.position.y * k


func _sand_y(x: float) -> float:
	return SAND_Y0 + (x) * SAND_SLOPE


## Requisite am Strand, Boden auf Sandhöhe
func _prop(path: String, parent: Node3D, node_name: String, x: float, z: float, size: float,
		height := false, yaw := 0.0, tilt := Vector3.ZERO, sink := 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	_own(holder, parent)
	holder.position = Vector3(x, _sand_y(x) - sink, z)
	holder.rotation = Vector3(tilt.x, yaw, tilt.z)
	var model := _instance(path, holder, "Model")
	_fit(model, size, height)
	return holder


# ---------- Aufbau ----------

func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.1
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.fog_enabled = true
	env.fog_density = 0.003
	env.fog_sky_affect = 0.4
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = env
	_own(world, scene)

	# Tief stehende Sonne hinter dem Schiff (Kamera schaut meist Richtung -Z)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(-0.16, PI + 0.5, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	_own(sun, scene)


func _sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(320, 320)
	plane.subdivide_width = 127
	plane.subdivide_depth = 127
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/prolog/sea.gdshader")
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(sea, scene)


func _ship() -> void:
	var ship := Node3D.new()
	ship.name = "Ship"
	_own(ship, scene)
	var model := _instance("res://assets/prolog/ship.glb", ship, "Model")
	model.rotation.y = SHIP_YAW
	_fit(model, SHIP_LENGTH)
	model.position.y -= SHIP_DRAFT

	# Der Held steht an Deck, Blick zum Bug, und studiert die Karte
	var hero := _instance(HERO_SCENE, ship, "Hero")
	hero.position = HERO_DECK
	hero.rotation.y = PI / 2.0
	var map := _instance("res://assets/prolog/map.glb", hero, "Map")
	map.scale = Vector3.ONE * 0.22
	map.position = Vector3(0.0, 1.05, 0.34)
	map.rotation = Vector3(-0.7, 0.0, 0.0)

	# Mannschaft: verschwindet mit dem Schiff, am Strand ist der Held allein
	var crew := Node3D.new()
	crew.name = "Crew"
	_own(crew, ship)
	var captain := Node3D.new()
	captain.name = "Captain"
	_own(captain, crew)
	captain.position = Vector3(-5.2, QUARTER_DECK_Y, 0.0)
	captain.rotation.y = PI / 2.0   # Blick zum Bug
	_fit(_instance("res://assets/prolog/captain.glb", captain, "Model"), 1.85, true)
	var sailors := Node3D.new()
	sailors.name = "Sailors"
	_own(sailors, crew)
	sailors.position = Vector3(3.0, MAIN_DECK_Y, 0.1)
	sailors.rotation.y = 0.4
	_fit(_instance("res://assets/prolog/sailors.glb", sailors, "Model"), 1.8, true)


func _reef() -> void:
	var reef := Node3D.new()
	reef.name = "Reef"
	reef.position = Vector3(150, 0, 0)
	_own(reef, scene)
	var rocks := [
		[Vector3(0, -1.2, -3.0), 6.0, 0.3],
		[Vector3(2.5, -1.5, 2.5), 5.0, 1.6],
		[Vector3(-2.0, -1.0, 6.5), 4.0, 2.4],
		[Vector3(4.0, -1.3, -7.5), 5.5, 0.9],
		[Vector3(6.0, -1.0, 4.0), 3.5, 4.0],
	]
	for i in rocks.size():
		var holder := Node3D.new()
		holder.name = "Rock%d" % (i + 1)
		_own(holder, reef)
		holder.position = rocks[i][0]
		holder.rotation.y = rocks[i][2]
		var model := _instance("res://assets/nature/rock_moss.glb", holder, "Model")
		_fit(model, rocks[i][1])


func _beach() -> void:
	var beach := Node3D.new()
	beach.name = "Beach"
	_own(beach, scene)

	# Sandbank, die aus dem Wasser zum Dschungel ansteigt
	var box := BoxMesh.new()
	box.size = Vector3(90, 2, 80)
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.84, 0.72, 0.52)
	sand_mat.roughness = 1.0
	var sand := MeshInstance3D.new()
	sand.name = "Sand"
	sand.mesh = box
	sand.material_override = sand_mat
	var a := atan(SAND_SLOPE)
	sand.rotation.z = a
	var cx := 20.0
	# Oberkante in der Mitte auf _sand_y(cx)
	sand.position = Vector3(cx, _sand_y(cx) - 1.0 / cos(a), 0)
	_own(sand, beach)

	var hero := _instance(HERO_SCENE, beach, "Hero")
	hero.position = Vector3(0, _sand_y(0), 0)
	hero.rotation.y = PI / 2.0

	var wreck := Node3D.new()
	wreck.name = "Wreck"
	_own(wreck, beach)
	wreck.position = Vector3(-7.0, -1.7, -11.0)
	wreck.rotation = Vector3(0.08, 0.55, 0.22)
	_fit(_instance("res://assets/prolog/wreck.glb", wreck, "Model"), 12.0)

	var debris := Node3D.new()
	debris.name = "Wrackteile"
	_own(debris, beach)
	_prop("res://assets/props/crate.glb", debris, "Crate1", -1.2, -3.6, 0.9, false, 0.4, Vector3(0, 0, 0.1), 0.15)
	_prop("res://assets/props/crate.glb", debris, "Crate2", 4.5, -4.8, 0.8, false, 1.1)
	_prop("res://assets/props/barrel.glb", debris, "Barrel1", 2.2, -2.4, 1.0, false, 0.3, Vector3(0, 0, PI / 2.0), -0.35)
	_prop("res://assets/props/barrel.glb", debris, "Barrel2", -4.0, 5.5, 1.0, false, 0.0, Vector3(0.2, 0, 0), 0.3)
	_prop("res://assets/deco/driftwood.glb", debris, "Driftwood1", -4.2, 1.9, 2.6, false, 0.7)
	_prop("res://assets/deco/driftwood.glb", debris, "Driftwood2", 3.6, 3.4, 2.2, false, 2.2)
	_prop("res://assets/deco/driftwood.glb", debris, "Driftwood3", -5.0, -5.5, 3.0, false, 1.4, Vector3.ZERO, 0.2)

	var jungle := Node3D.new()
	jungle.name = "Dschungel"
	_own(jungle, beach)
	var palm := "res://assets/nature/palm.glb"
	_prop(palm, jungle, "Palm1", 10.0, -8.0, 8.0, true, 0.3, Vector3(0, 0, 0.12))
	_prop(palm, jungle, "Palm2", 13.0, 5.5, 9.0, true, 1.7, Vector3(0.1, 0, 0))
	_prop(palm, jungle, "Palm3", 8.0, 11.0, 7.0, true, 2.9)
	_prop(palm, jungle, "Palm4", 16.0, -15.0, 9.5, true, 4.1)
	_prop(palm, jungle, "Palm5", 18.0, 14.0, 8.5, true, 5.0)
	var tree := "res://assets/nature/tree_large.glb"
	_prop(tree, jungle, "Tree1", 25.0, -6.0, 13.0, true, 0.5)
	_prop(tree, jungle, "Tree2", 27.0, 9.0, 14.0, true, 2.0)
	_prop(tree, jungle, "Tree3", 24.0, -20.0, 12.0, true, 3.3)
	_prop("res://assets/nature/jungle/giant_tree.glb", jungle, "GiantTree", 34.0, 1.0, 20.0, true, 1.0)
	var dense := "res://assets/nature/jungle/jungle_bush_dense.glb"
	_prop(dense, jungle, "Bush1", 20.0, 0.5, 4.0, true, 0.0)
	_prop(dense, jungle, "Bush2", 19.0, -11.0, 3.5, true, 1.2)
	_prop(dense, jungle, "Bush3", 21.0, 12.0, 4.0, true, 2.5)
	_prop(dense, jungle, "Bush4", 22.0, -3.5, 3.5, true, 3.7)
	_prop("res://assets/nature/big_leaves.glb", jungle, "Leaves1", 17.0, 4.0, 2.0, true, 0.6)
	_prop("res://assets/nature/big_leaves.glb", jungle, "Leaves2", 16.5, -5.0, 1.8, true, 2.1)
	_prop("res://assets/nature/bush.glb", jungle, "Bush5", 15.0, -1.0, 1.6, true, 1.0)
	_prop("res://assets/nature/bush.glb", jungle, "Bush6", 14.0, 9.0, 1.6, true, 4.0)
	_prop("res://assets/nature/jungle/monstera.glb", jungle, "Monstera", 18.0, 7.5, 2.2, true, 0.8)


func _camera() -> void:
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 55.0
	cam.far = 400.0
	_own(cam, scene)

	# Regen fällt in der Welt, wird aber immer über der Kamera erzeugt
	var rain := GPUParticles3D.new()
	rain.name = "Rain"
	rain.position = Vector3(0, 9, -6)
	rain.amount = 3000
	rain.lifetime = 0.9
	rain.local_coords = false
	rain.emitting = false
	rain.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 1, 16)
	pm.direction = Vector3(0.12, -1, 0)
	pm.spread = 3.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 26.0
	pm.gravity = Vector3(0, -6, 0)
	rain.process_material = pm
	var drop := BoxMesh.new()
	drop.size = Vector3(0.015, 0.7, 0.015)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.albedo_color = Color(0.75, 0.8, 0.9, 0.35)
	drop.material = drop_mat
	rain.draw_pass_1 = drop
	_own(rain, cam)

	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	_own(anim_player, scene)


# ---------- Zeitleiste ----------

func _timeline() -> void:
	var h := HERO_DECK
	var chest := h + Vector3(0, 1.3, 0)
	# Kameraeinstellungen: [Zeit, Position, Blickpunkt]. Zwei Keys im Abstand von 0,02 s = Schnitt.
	var shots := [
		# 1 – Ruhige See bei Abendlicht
		[0.0, Vector3(-26, 5, 30), Vector3(0, 4, 0)],
		[6.0, Vector3(-12, 4.5, 20), Vector3(0, 4, 0)],
		[6.02, h + Vector3(2.8, 2.0, 2.4), chest],
		[10.0, h + Vector3(2.1, 1.8, 1.7), chest],
		# 2 – Der Sturm zieht auf
		[10.02, Vector3(6, 9, 26), Vector3(0, 4, 0)],
		[20.0, Vector3(-4, 7, 19), Vector3(0, 4, 0)],
		# 3 – Das Unglück: über das Heck nach vorn aufs Riff
		[20.02, Vector3(-20, 10, 7), Vector3(35, 1, 0)],
		[26.3, Vector3(-14, 8.5, 5), Vector3(25, 1, 0)],
		# ... der Held geht über Bord
		[26.32, h + Vector3(-4.5, 3.0, 8.5), h + Vector3(0, 0.8, 2.0)],
		[29.5, h + Vector3(-4.0, 2.6, 10.0), h + Vector3(0, -0.5, 4.5)],
		[29.52, h + Vector3(-4, 3.5, 19), h + Vector3(0, 0, 8)],
		[35.0, h + Vector3(-3, 5, 21), h + Vector3(0, 0, 8)],
		# 4 – Schwarzblende (Kamera schon am Strand)
		[35.02, Vector3(1.6, 1.3, 3.6), Vector3(-1.6, 0.2, -2.4)],
		# 5 – Erwachen am Ufer (Wrack im Hintergrund), dann hinter den Helden
		[40.0, Vector3(1.6, 1.3, 3.6), Vector3(-1.6, 0.2, -2.4)],
		[45.0, Vector3(0.6, 1.5, 3.4), Vector3(-0.8, 0.8, -1.0)],
		[51.0, Vector3(-3.4, 2.1, 0.0), Vector3(3.0, 1.3, 0)],
		[LENGTH, Vector3(-3.4, 2.1, 0.0), Vector3(3.0, 1.3, 0)],
	]

	var anim := Animation.new()
	anim.length = LENGTH
	var pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pos, NodePath("Camera:position"))
	var rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot, NodePath("Camera:quaternion"))
	for shot in shots:
		var eye: Vector3 = shot[1]
		anim.track_insert_key(pos, shot[0], eye)
		anim.track_insert_key(rot, shot[0], Transform3D().looking_at(shot[2] - eye, Vector3.UP).basis.get_rotation_quaternion())

	var storm := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(storm, NodePath(".:storm"))
	for key in [[0.0, 0.0], [11.0, 0.0], [20.0, 0.65], [22.5, 1.0], [35.9, 1.0], [36.0, 0.0]]:
		anim.track_insert_key(storm, key[0], key[1])

	var volume := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(volume, NodePath(".:sea_volume"))
	for key in [[0.0, 1.0], [35.0, 1.0], [37.2, 0.0], [38.6, 0.0], [40.5, 0.4]]:
		anim.track_insert_key(volume, key[0], key[1])

	var reef := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(reef, NodePath("Reef:position"))
	for key in [[0.0, Vector3(150, 0, 0)], [19.98, Vector3(150, 0, 0)], [20.0, Vector3(30, 0, 0)], [26.5, Vector3(11, 0, 0)]]:
		anim.track_insert_key(reef, key[0], key[1])

	var calls := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(calls, NodePath("."))
	var events := [
		[0.2, &"fade", [0.0, 2.0]],
		[1.5, &"title", ["Auf der Suche nach El Dorado …"]],
		[7.0, &"title", [""]],
		[21.0, &"lightning", []],
		[24.2, &"lightning", []],
		[26.5, &"crash", []],
		[27.0, &"map_fly", []],
		[27.6, &"hero_overboard", []],
		[30.2, &"lightning", []],
		[32.6, &"lightning", []],
		[33.5, &"fade", [1.0, 1.5]],
		[36.0, &"to_beach", []],
		[38.6, &"birds", [true]],
		[40.0, &"fade", [0.0, 2.5]],
		[41.0, &"title", ["Irgendwo an einer fremden Küste …"]],
		[43.0, &"stand_up", []],
		[45.0, &"title", [""]],
	]
	for e in events:
		anim.track_insert_key(calls, e[0], {"method": e[1], "args": e[2]})

	var lib := AnimationLibrary.new()
	lib.add_animation(&"prolog", anim)
	(scene.get_node("AnimationPlayer") as AnimationPlayer).add_animation_library(&"", lib)
