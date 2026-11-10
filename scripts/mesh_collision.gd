extends Node3D
## Erzeugt beim Start eine statische Kollision aus allen Meshes unterhalb dieses Knotens.
## Für unregelmäßige Meshy-Ruinen (scenes/ruins/ruin_*.tscn), bei denen eine Box nicht passt.

@export var concave: bool = true   ## true: exakte Form (Trimesh), false: konvexe Hülle (günstiger)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for mi in find_children("*", "MeshInstance3D", true, false):
		if concave:
			(mi as MeshInstance3D).create_trimesh_collision()
		else:
			(mi as MeshInstance3D).create_convex_collision()
