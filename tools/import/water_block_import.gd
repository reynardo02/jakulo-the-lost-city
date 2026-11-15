@tool
extends EditorScenePostImport
## Post-Import-Script für assets/terrain/Meshy_AI_Sapphire_Water_Block_*.glb:
## Ersetzt nur das Aussehen durch das Low-Poly-Meer vom Strand (assets/terrain/water_material.tres).
##
## Die Oberseite des Meshy-Blocks hat zu wenige Punkte für Wellen. Deshalb bekommt jeder Block
## eine fein unterteilte Wasserfläche obendrauf, und das Block-Mesh wird nur ausgeblendet.
## Die beim Import erzeugte Kollision bleibt unverändert, Schaden machen weiterhin die KillZones.

const MATERIAL := "res://assets/terrain/water_material.tres"
## In den Leveln liegen die Blöcke mit Skalierung 1.21 im 4-m-Raster: 4 / 1.21 = 3.3058,
## so schließen die Flächen lückenlos aneinander an.
const SURFACE_SIZE := 4.0 / 1.21
const SURFACE_SUBDIVIDE := 5
## Höhe der Wasserfläche über der Blockoberkante (= Bodenhöhe). In Level 2 liegt eine Bodenplatte
## bei y = -0.02 über dem Kanal: Mit 0.1 und Wellen von ±0.08 bleibt das Wasser immer darüber.
const SURFACE_LIFT := 0.1


func _post_import(scene: Node) -> Object:
	var material := load(MATERIAL) as Material
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var block := node as MeshInstance3D
		var top := block.get_aabb().end.y

		var plane := PlaneMesh.new()
		plane.size = Vector2(SURFACE_SIZE, SURFACE_SIZE)
		plane.subdivide_width = SURFACE_SUBDIVIDE
		plane.subdivide_depth = SURFACE_SUBDIVIDE
		var surface := MeshInstance3D.new()
		surface.name = "WaterSurface"
		surface.mesh = plane
		surface.material_override = material
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		surface.transform = block.transform
		surface.position.y += top + SURFACE_LIFT
		block.get_parent().add_child(surface)
		surface.owner = scene

		block.visible = false
	return scene
