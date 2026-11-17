extends Node3D
## Hauptmenü-Szene: der Strand aus Level 1 im Morgenlicht als Hintergrund. Die Kamera
## gleitet langsam am Ufer entlang und blickt aufs Meer und das Wrack.
## Das Menü selbst ist der Autoload "Menu".

@export var sweep: float = 9.0          ## so weit (m) gleitet die Kamera seitlich hin und her
@export var sweep_time: float = 70.0    ## Sekunden für einen Hin- und Rückweg
@export var camera_height: float = 2.6
@export var camera_z: float = 5.0
@export var look_target := Vector3(-3.0, 0.4, 26.0)

@onready var _camera: Camera3D = $Camera3D

var _t := 0.0


func _ready() -> void:
	Menu.show_main_menu()
	_update_camera()


func _process(delta: float) -> void:
	_t += delta
	_update_camera()


func _update_camera() -> void:
	var s := sin(_t / sweep_time * TAU)
	_camera.position = Vector3(s * sweep, camera_height + sin(_t * 0.4) * 0.12, camera_z)
	_camera.look_at(to_global(look_target + Vector3(s * sweep * 0.4, 0, 0)), Vector3.UP)
