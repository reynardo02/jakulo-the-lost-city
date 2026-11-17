extends Node3D
## Halter für den geriggten Affen (assets/level3/monkey/monkey_rigged.glb, Kind dieses Knotens).
## Hängt beim Start die Animationen aus Meshy als Bibliothek "monkey" an den AnimationPlayer
## des Modells. Andere Skripte (sleeping_monkey.gd, scared_animal.gd) rufen play_anim() auf.
## Animationen: sleep, idle, throw, angry, running, walking (tools/level3/extract_monkey_anims.gd).

const DIR := "res://assets/level3/monkey/"
const NAMES := ["sleep", "idle", "throw", "angry", "running", "walking"]

@export var start_animation: StringName = &"idle"

var _player: AnimationPlayer


func _ready() -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	_player = players[0]
	var library := AnimationLibrary.new()
	for anim_name in NAMES:
		var anim := load(DIR + "anim_%s.res" % anim_name) as Animation
		if anim:
			library.add_animation(anim_name, anim)
	_player.add_animation_library(&"monkey", library)
	# jeder Affe beginnt an einer anderen Stelle, damit eine Gruppe nicht im Gleichtakt atmet
	play_anim(start_animation, 0.0)
	_player.seek(randf() * _player.current_animation_length, true)


## Spielt eine Animation (überblendet) und gibt ihre Dauer bei dieser Geschwindigkeit zurück.
func play_anim(anim_name: StringName, blend: float = 0.3, speed: float = 1.0) -> float:
	if _player == null:
		return 0.0
	var full := StringName("monkey/" + anim_name)
	if not _player.has_animation(full):
		return 0.0
	_player.play(full, blend, speed)
	return _player.get_animation(full).length / maxf(speed, 0.01)
