extends Light3D
## Flackerndes Feuerlicht (Fackeln, Lagerfeuer): Helligkeit und Lage schwanken unruhig,
## wie bei einer echten Flamme. Grundwerte sind die im Editor gesetzten.

@export var strength: float = 0.25   ## Anteil, um den die Helligkeit schwankt
@export var speed: float = 9.0       ## wie unruhig die Flamme ist
@export var wobble: float = 0.04     ## so weit (m) wandert das Licht mit der Flamme

var _base_energy := 1.0
var _base_pos := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	_base_energy = light_energy
	_base_pos = position
	_t = randf() * 100.0


func _process(delta: float) -> void:
	_t += delta * speed
	# Überlagerte Schwingungen ergeben ein unregelmäßiges, nie gleiches Flackern
	var f := sin(_t) * 0.5 + sin(_t * 2.3 + 1.7) * 0.3 + sin(_t * 5.1 + 0.4) * 0.2
	light_energy = _base_energy * (1.0 + f * strength)
	position = _base_pos + Vector3(sin(_t * 1.3), sin(_t * 0.7) * 0.5, cos(_t * 1.1)) * wobble
