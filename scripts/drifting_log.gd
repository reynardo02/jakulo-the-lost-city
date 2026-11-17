extends AnimatableBody3D
## Treibholz, das auf dem Wasser hin und her treibt. Wer darauf steht, fährt mit.
## Es pendelt zwischen der Startposition und Startposition + `travel` und wartet an beiden
## Enden kurz. Steigendes Wasser hebt es über `water_offset` an.

@export var travel: Vector3 = Vector3(6, 0, 0)
@export var speed: float = 1.4          ## m/s
@export var pause_time: float = 0.8     ## Wartezeit an den Enden
@export var bob_height: float = 0.05    ## leichtes Schaukeln auf den Wellen
@export var phase: float = 0.0          ## Startversatz 0 .. 1

## Wasserstand über der Ausgangshöhe (setzt rising_water.gd, wenn das Wasser steigt)
var water_offset: float = 0.0

var _start := Vector3.ZERO
var _t := 0.0
var _cycle := 1.0


func _ready() -> void:
	_start = position
	var move_time := travel.length() / maxf(speed, 0.01)
	_cycle = 2.0 * (move_time + pause_time)
	_t = phase * _cycle


func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, _cycle)
	var move_time := (_cycle - 2.0 * pause_time) * 0.5
	var f := 0.0
	if _t < move_time:
		f = _t / move_time
	elif _t < move_time + pause_time:
		f = 1.0
	elif _t < 2.0 * move_time + pause_time:
		f = 1.0 - (_t - move_time - pause_time) / move_time
	f = smoothstep(0.0, 1.0, f)
	position = _start + travel * f + Vector3.UP * (sin(_t * 2.3) * bob_height + water_offset)
	rotation.z = sin(_t * 1.7) * 0.03
