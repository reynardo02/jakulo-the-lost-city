extends SceneTree
## Holt die Animationen aus croc_hang.glb (von build_anim.py) und speichert sie als .res
## für die Bibliothek "extra" des Spielers.
## Aufruf: godot --headless --path . -s res://tools/croc_hang_anim/extract_anims.gd

const SRC := "res://tools/croc_hang_anim/croc_hang.glb"
const REF := "res://assets/character/Meshy_AI_Adventure_Scout_All_Animations(1).glb"
const OUT := {
	"Croc_Jaw_Brace": ["res://assets/character/anims/croc_jaw_brace.res", Animation.LOOP_LINEAR],
	"Croc_Jaw_Push": ["res://assets/character/anims/croc_jaw_push.res", Animation.LOOP_NONE],
}


func _init() -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(SRC), state) != OK:
		push_error("Kann %s nicht laden" % SRC)
		quit(1)
		return
	var scene := doc.generate_scene(state)
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]

	# Gültige Pfade aus dem Original-Modell
	var ref_anim: Animation = load(REF).instantiate().get_node("AnimationPlayer").get_animation("Idle_9")
	var valid := {}
	for i in ref_anim.get_track_count():
		valid[ref_anim.track_get_path(i)] = true

	for anim_name in OUT:
		var anim := player.get_animation(anim_name).duplicate(true) as Animation
		for i in range(anim.get_track_count() - 1, -1, -1):
			var path := anim.track_get_path(i)
			var keep := valid.has(path) and (anim.track_get_type(i) == Animation.TYPE_ROTATION_3D
				or (anim.track_get_type(i) == Animation.TYPE_POSITION_3D and str(path).ends_with("mixamorig_Hips")))
			if not keep:
				anim.remove_track(i)
		anim.loop_mode = OUT[anim_name][1]
		anim.resource_name = anim_name
		ResourceSaver.save(anim, OUT[anim_name][0])
		print("%s: %d Tracks, %.2fs -> %s" % [anim_name, anim.get_track_count(), anim.length, OUT[anim_name][0]])
	quit()
