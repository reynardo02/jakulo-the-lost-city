@tool
extends Node3D
## Organische Sumpfinsel (Level 3) statt eckiger Bodenkacheln.
##
## Die begehbare Fläche ist mindestens das Rechteck `half_size` (± x/z um den Knoten,
## Oberkante bei lokal y = 0). Der Rand wölbt sich unregelmäßig nach außen, höchstens um
## `max_bulge` je Seite (-x, +x, -z, +z). So werden Sprünge nie länger als mit den alten
## Kacheln, aber kein Ufer sieht aus wie ein Klotz.
##
## Oben liegt Gras (Material der Bodenkacheln), außen fällt eine Böschung aus Erde und
## nassem Schlamm unter die Wasserlinie ab. Mesh und Kollision entstehen beim Start (auch im
## Editor) und werden nicht in der Szene gespeichert. `grass_field.gd` streut Halme auf die
## Oberseite (random_top_point / top_area).

const GRASS_MATERIAL := preload("res://assets/terrain/materials/grass_ground.tres")
const BANK_SHADER := preload("res://assets/terrain/swamp_bank.gdshader")
const ROUND := 0.3       # Grundrundung der Ecken (m)
const SPACING := 0.45    # Abstand der Randpunkte (m)
const RIM := 0.35        # so weit vor dem Rand beginnt die Rundung der Oberkante

@export var half_size := Vector2(2.0, 2.0):
	set(value):
		half_size = value
		_rebuild()
@export var max_bulge := Vector4(0.7, 0.7, 0.7, 0.7):   ## -x, +x, -z, +z
	set(value):
		max_bulge = value
		_rebuild()
@export var island_seed: int = 1:
	set(value):
		island_seed = value
		_rebuild()
@export var solid: bool = true   ## aus = nur Kulisse (Schlammbank ohne Kollision)

var _top_polygon := PackedVector2Array()
var _top_area := 0.0
var _built := false


func _ready() -> void:
	_built = true
	_rebuild()


## Randpunkte (lokal x/z) und ihre Außennormalen, gegen den Uhrzeigersinn von oben gesehen.
static func outline(half: Vector2, bulge: Vector4, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var base: Array[Vector2] = []
	var normals: Array[Vector2] = []
	var corners := [Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y)]
	for k in 4:
		var a: Vector2 = corners[k]
		var b: Vector2 = corners[(k + 1) % 4]
		var theta0 := -PI / 2.0 + k * PI / 2.0
		var arc_steps := maxi(2, int(ROUND * PI / 2.0 / SPACING) + 2)
		for i in arc_steps:
			var th := theta0 + PI / 2.0 * float(i) / arc_steps
			var n := Vector2(cos(th), sin(th))
			base.append(a + n * ROUND)
			normals.append(n)
		var edge_n := Vector2(cos(theta0 + PI / 2.0), sin(theta0 + PI / 2.0))
		var length := a.distance_to(b)
		var steps := maxi(1, int(length / SPACING))
		for i in steps:
			base.append(a.lerp(b, float(i) / steps) + edge_n * ROUND)
			normals.append(edge_n)
	# weiche, umlaufend periodische Ausbuchtungen + feines Zittern
	var perimeter := 0.0
	for i in base.size():
		perimeter += base[i].distance_to(base[(i + 1) % base.size()])
	var k1 := maxf(1.0, roundf(perimeter / 7.0))
	var k2 := maxf(2.0, roundf(perimeter / 2.6))
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var points := PackedVector2Array()
	var out_normals := PackedVector2Array()
	var s := 0.0
	for i in base.size():
		var n: Vector2 = normals[i]
		var wx := absf(n.x)
		var wz := absf(n.y)
		var side_x := bulge.y if n.x > 0.0 else bulge.x
		var side_z := bulge.w if n.y > 0.0 else bulge.z
		var limit := (wx * side_x + wz * side_z) / maxf(wx + wz, 0.001)
		var t := s / perimeter * TAU
		var b := clampf(0.5 + 0.32 * sin(t * k1 + p1) + 0.18 * sin(t * k2 + p2), 0.0, 1.0)
		var offset := limit * b + rng.randf() * minf(0.06, limit)
		points.append(base[i] + n * offset)
		out_normals.append(n)
		s += base[i].distance_to(base[(i + 1) % base.size()])
	return [points, out_normals]


func top_area() -> float:
	return _top_area


## Zufälliger Punkt auf der Grasfläche (global) für grass_field.gd.
func random_top_point(rng: RandomNumberGenerator) -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in _top_polygon:
		lo = lo.min(p)
		hi = hi.max(p)
	for _attempt in 12:
		var p := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		if Geometry2D.is_point_in_polygon(p, _top_polygon):
			return global_transform * Vector3(p.x, 0.0, p.y)
	return global_transform * Vector3.ZERO


func _rebuild() -> void:
	if not _built:
		return
	for child in get_children():
		if child.has_meta("generated"):
			remove_child(child)
			child.queue_free()
	var data := outline(half_size, max_bulge, island_seed)
	var points: PackedVector2Array = data[0]
	var normals: PackedVector2Array = data[1]
	var count := points.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = island_seed * 7919 + 13

	# Ringe von innen nach außen: (horizontaler Abstand zum Rand, Höhe)
	var rings: Array[PackedVector3Array] = []
	var ring_defs := [[-RIM, 0.0], [0.0, -0.06], [0.24, -0.24], [0.55, -0.62], [1.0, -2.0]]
	for r in ring_defs.size():
		var ring := PackedVector3Array()
		for i in count:
			var jitter := 0.0 if r < 2 else rng.randf_range(-0.06, 0.06)
			var dy := 0.0 if r < 2 else rng.randf_range(-0.05, 0.05)
			var p: Vector2 = points[i] + normals[i] * (float(ring_defs[r][0]) + jitter)
			ring.append(Vector3(p.x, float(ring_defs[r][1]) + dy, p.y))
		rings.append(ring)

	# Grasfläche: Polygon des inneren Rings + Rundung zum Rand
	_top_polygon = PackedVector2Array()
	for v in rings[0]:
		_top_polygon.append(Vector2(v.x, v.z))
	_top_area = absf(_polygon_area(_top_polygon)) if solid else 0.0   # Schlammbänke tragen kein Gras
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(_top_polygon)
	for i in range(0, tris.size(), 3):
		_tri(top, rings[0][tris[i]], rings[0][tris[i + 1]], rings[0][tris[i + 2]], Vector3.UP)
	_strip(top, rings[0], rings[1])
	top.index()
	top.generate_normals()
	var mesh := top.commit()
	var bank_material := ShaderMaterial.new()
	bank_material.shader = BANK_SHADER
	if not solid:
		bank_material.set_shader_parameter("grass_amount", 0.0)
		bank_material.set_shader_parameter("waterline", 0.1)
	mesh.surface_set_material(0, GRASS_MATERIAL if solid else bank_material)

	var bank := SurfaceTool.new()
	bank.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(1, rings.size() - 1):
		_strip(bank, rings[r], rings[r + 1])
	bank.index()
	bank.generate_normals()
	mesh = bank.commit(mesh)
	mesh.surface_set_material(1, bank_material)

	var mi := MeshInstance3D.new()
	mi.name = "IslandMesh"
	mi.mesh = mesh
	mi.set_meta("generated", true)
	add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.name = "IslandBody"
		body.set_meta("generated", true)
		body.set_meta("footstep_surface", "earth")
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_trimesh_shape()
		body.add_child(shape)
		add_child(body)


## Dreieck mit der Vorderseite in Richtung `facing` (Godot: im Uhrzeigersinn von vorn).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, facing: Vector3) -> void:
	if (b - a).cross(c - a).dot(facing) > 0.0:
		var tmp := b
		b = c
		c = tmp
	st.set_uv(Vector2(a.x, a.z))
	st.add_vertex(a)
	st.set_uv(Vector2(b.x, b.z))
	st.add_vertex(b)
	st.set_uv(Vector2(c.x, c.z))
	st.add_vertex(c)


## Band zwischen zwei Ringen, Vorderseite nach außen/oben.
func _strip(st: SurfaceTool, inner: PackedVector3Array, outer: PackedVector3Array) -> void:
	var n := inner.size()
	for i in n:
		var j := (i + 1) % n
		var out_dir := Vector3(outer[i].x - inner[i].x, 0.0, outer[i].z - inner[i].z).normalized()
		var facing := (out_dir + Vector3.UP * 0.5).normalized()
		_tri(st, inner[i], outer[i], outer[j], facing)
		_tri(st, inner[i], outer[j], inner[j], facing)


static func _polygon_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return area * 0.5
