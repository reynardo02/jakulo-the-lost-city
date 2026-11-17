extends Node
## Verteilt Grashalme über alle Gras-Bodenkacheln, die direkte Kinder dieses Knotens sind.
## Die Halme werden in Blöcken (chunk_size) zu MultiMeshes gebündelt -> wenige Draw Calls,
## und Godot kann Blöcke außerhalb der Kamera wegschneiden.

const BLADE_SHADER := preload("res://assets/terrain/materials/grass_blades.gdshader")
const GRASS_TEXTURE := preload("res://assets/terrain/materials/grass_albedo.png")
const TILE_HALF := 2.0   # Bodenkacheln sind 4 x 4 m, Grasoberfläche bei lokal y = 0

@export var tile_scenes: PackedStringArray = [
	"res://assets/terrain/ground_straight.glb",
	"res://assets/terrain/ground_end.glb",
	"res://assets/terrain/ground_narrow.glb",
	"res://assets/terrain/ground_corner_inner.glb",
	"res://assets/terrain/ground_corner_outer.glb",
]
@export var blades_per_m2: float = 40.0
@export var blade_height: Vector2 = Vector2(0.18, 0.42)   ## min / max in Metern
@export var blade_width: float = 0.05
@export var chunk_size: float = 16.0
@export var visibility_range: float = 60.0                ## Meter, danach werden Halme ausgeblendet
@export var random_seed: int = 1234
## World-space x/z endpoints, at most eight paths. High-grass hiding zones stay separate.
@export var worn_paths: Array[Vector4] = []
@export var path_half_width: float = 0.8
@export_range(0.0, 1.0) var path_opacity: float = 0.82
@export_range(0.0, 1.0) var path_grass_retention: float = 0.0


func _ready() -> void:
	var path_material: ShaderMaterial
	if not worn_paths.is_empty():
		path_material = ShaderMaterial.new()
		path_material.shader = preload("res://assets/terrain/worn_path.gdshader")
		var padded := worn_paths.duplicate()
		padded.resize(8)
		path_material.set_shader_parameter("paths", padded)
		path_material.set_shader_parameter("path_count", mini(worn_paths.size(), 8))
		path_material.set_shader_parameter("width", path_half_width)
		path_material.set_shader_parameter("opacity", path_opacity)
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var chunks := {}   # Vector2i -> Array[Transform3D]
	var per_tile := int(blades_per_m2 * (TILE_HALF * 2.0) * (TILE_HALF * 2.0))

	for tile in get_children():
		if tile.has_method("random_top_point"):
			_scatter_on_island(tile, rng, chunks)
			continue
		if not (tile is Node3D and tile.scene_file_path in tile_scenes):
			continue
		var xf: Transform3D = (tile as Node3D).global_transform
		if path_material:
			for mi in tile.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = path_material
		for i in per_tile:
			var local := Vector3(rng.randf_range(-TILE_HALF, TILE_HALF), 0.0, rng.randf_range(-TILE_HALF, TILE_HALF))
			var pos: Vector3 = xf * local
			var on_path := _on_path(Vector2(pos.x, pos.z))
			if on_path and (path_grass_retention <= 0.0 or rng.randf() >= path_grass_retention):
				continue
			var h := rng.randf_range(blade_height.x, blade_height.y)
			if on_path:
				h *= 0.55
			var basis := Basis(Vector3.UP, rng.randf() * TAU) \
					* Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25)) \
					* Basis.from_scale(Vector3(1.0, h, 1.0))
			var key := Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))
			if not chunks.has(key):
				chunks[key] = []
			chunks[key].append(Transform3D(basis, pos))

	var mesh := _make_blade_mesh()
	for key in chunks:
		var xforms: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Grass_%d_%d" % [key.x, key.y]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = visibility_range
		mmi.visibility_range_end_margin = 8.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)

## Organische Inseln (swamp_island.gd) liefern selbst Punkte auf ihrer Grasfläche.
func _scatter_on_island(island: Node, rng: RandomNumberGenerator, chunks: Dictionary) -> void:
	var count := int(blades_per_m2 * float(island.call("top_area")))
	for i in count:
		var pos: Vector3 = island.call("random_top_point", rng)
		var h := rng.randf_range(blade_height.x, blade_height.y)
		var basis := Basis(Vector3.UP, rng.randf() * TAU) 				* Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25)) 				* Basis.from_scale(Vector3(1.0, h, 1.0))
		var key := Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(Transform3D(basis, pos))


func _on_path(point: Vector2) -> bool:
	for line in worn_paths:
		var a := Vector2(line.x, line.y)
		var b := Vector2(line.z, line.w)
		var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
		if point.distance_to(closest) < path_half_width:
			return true
	return false


## Ein Halm: 1 m hoch (wird pro Instanz skaliert), spitz zulaufend, leicht gebogen
func _make_blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 3
	var pts: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	for s in segments + 1:
		var t := float(s) / segments          # 0 = Wurzel, 1 = Spitze
		var w := blade_width * (1.0 - t) * 0.5
		var lean := t * t * 0.18
		pts.append(Vector3(-w, t, lean)); uvs.append(Vector2(0.0, 1.0 - t))
		pts.append(Vector3(w, t, lean)); uvs.append(Vector2(1.0, 1.0 - t))
	for s in segments:
		var a := s * 2
		for idx in [a, a + 1, a + 2, a + 1, a + 3, a + 2]:
			st.set_normal(Vector3(0, 0.5, -1).normalized())
			st.set_uv(uvs[idx])
			st.add_vertex(pts[idx])
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = BLADE_SHADER
	mat.set_shader_parameter("albedo_tex", GRASS_TEXTURE)
	mesh.surface_set_material(0, mat)
	return mesh
