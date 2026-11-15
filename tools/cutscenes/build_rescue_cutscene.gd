extends SceneTree
## Erzeugt scenes/village/rescue_cutscene.tscn: die Befreiung des Dorfbewohners in Level 2.
## Die Zeitleiste lässt sich danach ganz normal im Editor im AnimationPlayer bearbeiten;
## dieses Script braucht man nur, um sie von Grund auf neu zu erzeugen.
## Aufruf: godot --headless --path . -s res://tools/cutscenes/build_rescue_cutscene.gd
##
## Die Kamerapositionen sind Weltkoordinaten von Level 2 (Käfig bei (-8, -228), Podest bei
## (0, -228), Portal bei (0, -232)). Die Szene gehört deshalb ohne Verschiebung ins Level.

const OUT := "res://scenes/village/rescue_cutscene.tscn"
const CAGE := "../Kaefig"   # Pfad vom Cutscene-Knoten zum Käfig im Level

# Kameraeinstellungen: [Zeit, Position, Blickpunkt]
const SHOTS := [
	[0.0, Vector3(-3.6, 1.9, -223.2), Vector3(-7.4, 1.25, -228.0)],    # Käfig von vorn rechts
	[4.58, Vector3(-4.3, 1.7, -224.4), Vector3(-6.6, 1.25, -228.0)],    # langsam heranfahren
	[4.6, Vector3(-8.6, 2.3, -223.4), Vector3(-0.8, 1.5, -230.2)],     # Schnitt: Podest und Portal
	[9.2, Vector3(-7.2, 2.1, -224.6), Vector3(-0.3, 1.7, -231.0)],
]
const LENGTH := 9.2


func _initialize() -> void:
	_build()


func _build() -> void:
	await process_frame   # erst dann gibt es die Autoloads, die cutscene.gd braucht
	var root := Node3D.new()
	root.name = "RescueCutscene"
	root.set_script(load("res://scripts/cutscene.gd"))

	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.fov = 50.0
	root.add_child(camera)
	camera.owner = root

	var anim := Animation.new()
	anim.length = LENGTH
	var pos := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pos, NodePath("Camera:position"))
	var rot := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(rot, NodePath("Camera:quaternion"))
	for shot in SHOTS:
		var eye: Vector3 = shot[1]
		anim.track_insert_key(pos, shot[0], eye)
		anim.track_insert_key(rot, shot[0], Transform3D().looking_at(shot[2] - eye, Vector3.UP).basis.get_rotation_quaternion())

	var own := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(own, NodePath("."))
	anim.track_insert_key(own, 0.9, {"method": &"say", "args": ["Dorfbewohner", "Danke, Fremder! Das werde ich dir nicht vergessen."]})
	anim.track_insert_key(own, 4.8, {"method": &"say", "args": ["Dorfbewohner", "Nimm meine Trinkflasche. Das Portal steht dir jetzt offen."]})
	anim.track_insert_key(own, 8.9, {"method": &"clear_text", "args": []})

	var cage := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(cage, NodePath(CAGE))
	anim.track_insert_key(cage, 0.5, {"method": &"step_out", "args": []})
	anim.track_insert_key(cage, 5.6, {"method": &"complete", "args": []})   # Flasche erscheint, Portal leuchtet auf

	var library := AnimationLibrary.new()
	library.add_animation(&"cutscene", anim)
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	player.add_animation_library(&"", library)
	root.add_child(player)
	player.owner = root

	var scene := PackedScene.new()
	scene.pack(root)
	var err := ResourceSaver.save(scene, OUT)
	print("gespeichert: ", OUT, " (Fehlercode ", err, ")")
	quit()
