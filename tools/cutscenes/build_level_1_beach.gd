extends SceneTree
## Erzeugt scenes/level_1_beach.tscn: den Strand am Anfang von Level 1, passend zum Prolog.
## Die Szene hängt in Level 1 unter "Umgebung" (ein Node, kein Node3D), deshalb sind alle
## Positionen hier Weltkoordinaten von Level 1. Danach normal im Editor bearbeitbar.
## Aufruf: godot --headless --path . -s res://tools/cutscenes/build_level_1_beach.gd
##
## Der Dschungelpfad läuft in -Z. Er endet hinten bei z ≈ 2 (Graskacheln), dahinter fällt der
## Strand in +Z sanft zum Meer ab. Der Spieler startet bei (0, 0, 12) und läuft in den Pfad.

const OUT := "res://scenes/level_1_beach.tscn"
const SAND_START_Z := 2.0       # hier enden die Graskacheln des Pfads
const SAND_SLOPE := 0.04        # Gefälle Richtung Meer
const SEA_Y := -0.7
const WATERLINE_Z := 24.0       # unsichtbare Wand: so weit kann man ins flache Wasser

var scene: Node3D


func _initialize() -> void:
	_build()


func _build() -> void:
	await process_frame
	scene = Node3D.new()
	scene.name = "Strand"
	root.add_child(scene)

	_sand()
	_sea()
	_wreck()
	_vegetation()
	_bounds()

	root.remove_child(scene)
	var packed := PackedScene.new()
	var err := packed.pack(scene)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("level_1_beach.tscn: ", "gespeichert" if err == OK else "Fehler %d" % err)
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


func _aabb(node: Node3D) -> AABB:
	var inv := node.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (inv * (m as MeshInstance3D).global_transform) * (m as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _fit(node: Node3D, size: float, height := false) -> void:
	node.scale = Vector3.ONE
	var box := _aabb(node)
	var measure := box.size.y if height else maxf(box.size.x, maxf(box.size.y, box.size.z))
	var k := size / maxf(measure, 0.001)
	node.scale = Vector3.ONE * k
	node.position.y -= box.position.y * k


## Höhe der Sandoberfläche bei z
static func sand_y(z: float) -> float:
	return -maxf(z - SAND_START_Z, 0.0) * SAND_SLOPE


## Requisite auf dem Sand. `solid` erzeugt beim Start eine Kollision (scripts/mesh_collision.gd).
func _prop(path: String, parent: Node3D, node_name: String, x: float, z: float, size: float,
		height := false, yaw := 0.0, tilt := Vector3.ZERO, sink := 0.0, solid := false) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	_own(holder, parent)
	holder.position = Vector3(x, sand_y(z) - sink, z)
	holder.rotation = Vector3(tilt.x, yaw, tilt.z)
	_fit(_instance(path, holder, "Model"), size, height)
	if solid:
		holder.set_script(load("res://scripts/mesh_collision.gd"))
		holder.set("concave", false)
	return holder


# ---------- Aufbau ----------

func _sand() -> void:
	var length := 46.0
	var a := atan(SAND_SLOPE)
	var center_z := SAND_START_Z + length / 2.0
	var xform := Transform3D(Basis(Vector3.RIGHT, a), Vector3.ZERO)
	# Oberkante bei center_z auf sand_y(center_z)
	xform.origin = Vector3(0, sand_y(center_z) - 1.0 / cos(a), center_z)

	var box := BoxMesh.new()
	box.size = Vector3(200, 2, length)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.84, 0.72, 0.52)
	mat.roughness = 1.0
	box.material = mat
	var mesh := MeshInstance3D.new()
	mesh.name = "Sand"
	mesh.mesh = box
	mesh.transform = xform
	_own(mesh, scene)

	var body := StaticBody3D.new()
	body.name = "SandBoden"
	body.transform = xform
	_own(body, scene)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(60, 2, length)
	shape.shape = box_shape
	_own(shape, body)


func _sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(260, 160)
	plane.subdivide_width = 103
	plane.subdivide_depth = 63
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/prolog/sea.gdshader")
	mat.set_shader_parameter("wave_height", 0.25)
	mat.set_shader_parameter("calm_color", Color(0.03, 0.16, 0.24))   # etwas dunkler als im Prolog
	var sea := MeshInstance3D.new()
	sea.name = "Meer"
	sea.mesh = plane
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position = Vector3(0, SEA_Y, 18 + 80)
	_own(sea, scene)


func _wreck() -> void:
	var wreck := Node3D.new()
	wreck.name = "Wrack"
	_own(wreck, scene)
	wreck.position = Vector3(-9.5, sand_y(22.0) - 0.8, 22.0)
	wreck.rotation = Vector3(0.08, 0.9, 0.2)
	_fit(_instance("res://assets/prolog/wreck.glb", wreck, "Model"), 12.0)

	var debris := Node3D.new()
	debris.name = "Wrackteile"
	_own(debris, scene)
	_prop("res://assets/props/crate.glb", debris, "Crate1", -3.5, 9.0, 0.9, false, 0.4, Vector3(0, 0, 0.1), 0.15, true)
	_prop("res://assets/props/crate.glb", debris, "Crate2", 4.5, 15.5, 0.8, false, 1.1, Vector3.ZERO, 0.0, true)
	_prop("res://assets/props/crate.glb", debris, "Crate3", -5.5, 18.5, 0.8, false, 2.3, Vector3(0.15, 0, 0), 0.2, true)
	_prop("res://assets/props/barrel.glb", debris, "Barrel1", 3.0, 8.5, 1.0, false, 0.3, Vector3(0, 0, PI / 2.0), -0.35, true)
	_prop("res://assets/props/barrel.glb", debris, "Barrel2", -2.0, 20.5, 1.0, false, 0.0, Vector3(0.2, 0, 0), 0.3, true)
	_prop("res://assets/deco/driftwood.glb", debris, "Driftwood1", 1.5, 17.0, 2.6, false, 0.7)
	_prop("res://assets/deco/driftwood.glb", debris, "Driftwood2", -6.5, 13.0, 2.2, false, 2.2)
	_prop("res://assets/deco/driftwood.glb", debris, "Driftwood3", 6.0, 21.0, 3.0, false, 1.4, Vector3.ZERO, 0.2)


func _vegetation() -> void:
	var plants := Node3D.new()
	plants.name = "Pflanzen"
	_own(plants, scene)
	var palm := "res://assets/nature/palm.glb"
	_prop(palm, plants, "Palm1", -11.0, 6.0, 8.0, true, 0.3, Vector3(0, 0, 0.12))
	_prop(palm, plants, "Palm2", -12.5, 14.0, 9.0, true, 1.7, Vector3(0.1, 0, 0))
	_prop(palm, plants, "Palm3", 11.0, 5.0, 8.5, true, 2.9, Vector3(0, 0, -0.1))
	_prop(palm, plants, "Palm4", 12.5, 13.0, 9.5, true, 4.1)
	_prop(palm, plants, "Palm5", -16.0, 20.0, 8.0, true, 5.0)
	_prop(palm, plants, "Palm6", 16.5, 19.0, 8.5, true, 0.9)
	var bush := "res://assets/nature/bush.glb"
	_prop(bush, plants, "Bush1", -9.0, 4.0, 1.8, true, 0.5)
	_prop(bush, plants, "Bush2", 9.0, 3.5, 1.8, true, 2.0)
	_prop("res://assets/nature/big_leaves.glb", plants, "Leaves1", -10.0, 9.5, 1.8, true, 1.0)
	_prop("res://assets/nature/big_leaves.glb", plants, "Leaves2", 10.0, 9.0, 1.8, true, 3.0)
	_prop("res://assets/nature/jungle/jungle_bush_dense.glb", plants, "Dense1", -15.0, 4.0, 3.5, true, 0.2)
	_prop("res://assets/nature/jungle/jungle_bush_dense.glb", plants, "Dense2", 15.0, 4.0, 3.5, true, 1.8)


## Unsichtbare Wände: Strand an den Seiten und zum Meer hin, Anschluss an die Spielgrenze
## des Pfads (die bei z = -3 endet).
func _bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "StrandGrenze"
	_own(body, scene)
	var walls := {
		"LinksGang": [Vector3(-7, 6, -1), Vector3(1, 12, 5)],
		"RechtsGang": [Vector3(7, 6, -1), Vector3(1, 12, 5)],
		"LinksEcke": [Vector3(-10.5, 6, 1.5), Vector3(8, 12, 1)],
		"RechtsEcke": [Vector3(10.5, 6, 1.5), Vector3(8, 12, 1)],
		"Links": [Vector3(-14, 6, 13), Vector3(1, 12, 23)],
		"Rechts": [Vector3(14, 6, 13), Vector3(1, 12, 23)],
		"Meer": [Vector3(0, 6, WATERLINE_Z), Vector3(29, 12, 1)],
	}
	for wall_name in walls:
		var shape := CollisionShape3D.new()
		shape.name = wall_name
		shape.position = walls[wall_name][0]
		var box := BoxShape3D.new()
		box.size = walls[wall_name][1]
		shape.shape = box
		_own(shape, body)
