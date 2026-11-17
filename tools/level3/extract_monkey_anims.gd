extends SceneTree
## Übernimmt den geriggten Affen aus Meshy (Rigging + Animationen, siehe
## assets/meshy_output/20261116_231811_l3-monkey-rig_01a1e670) ins Spiel:
##   assets/level3/monkey/monkey_rigged.glb   das geriggte Modell (Kopie)
##   assets/level3/monkey/anim_<name>.res      je eine Animation (Spuren relativ zum Modell)
## scripts/monkey_animator.gd hängt die Animationen zur Laufzeit an das Modell.
## Aufruf: godot --headless --path . -s res://tools/level3/extract_monkey_anims.gd

const SRC := "res://assets/meshy_output/20261116_231811_l3-monkey-rig_01a1e670/anims/"
const OUT := "res://assets/level3/monkey/"
const ANIMS := {
	"sleep": Animation.LOOP_LINEAR,
	"idle": Animation.LOOP_LINEAR,
	"throw": Animation.LOOP_NONE,
	"angry": Animation.LOOP_NONE,
	"running": Animation.LOOP_LINEAR,
	"walking": Animation.LOOP_LINEAR,
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var err := DirAccess.copy_absolute(ProjectSettings.globalize_path(SRC + "rigged.glb"),
		ProjectSettings.globalize_path(OUT + "monkey_rigged.glb"))
	print("monkey_rigged.glb: ", "kopiert" if err == OK else "Fehler %d" % err)
	for anim_name in ANIMS:
		var scene := (load(SRC + anim_name + ".glb") as PackedScene).instantiate()
		var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var anim := player.get_animation(player.get_animation_list()[0]).duplicate(true) as Animation
		anim.loop_mode = ANIMS[anim_name]
		anim.resource_name = anim_name
		ResourceSaver.save(anim, OUT + "anim_%s.res" % anim_name)
		print("%s: %.2fs, %d Spuren" % [anim_name, anim.length, anim.get_track_count()])
		scene.free()
	quit()
