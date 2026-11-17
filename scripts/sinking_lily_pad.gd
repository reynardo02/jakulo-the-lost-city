extends AnimatableBody3D
## Seerose als Trittstein, die langsam versinkt.
## Solange der Spieler darauf steht, sinkt sie mit `sink_speed` ab. Liegt sie unter der
## Wasseroberfläche, steht der Spieler im Wasser und die KillZone des Wassers greift.
## Verlässt er sie vorher, taucht sie mit `rise_speed` wieder auf.
## Der Ursprung der Szene gehört auf die Wasseroberfläche.

@export var sink_speed: float = 0.1   ## m/s nach unten, solange der Spieler darauf steht
@export var rise_speed: float = 0.4   ## m/s zurück nach oben, wenn sie leer ist
@export var sink_depth: float = 0.6   ## so tief sinkt sie höchstens
@export var note_id: String = "lily_pad"  ## Notiz im Buch, die beim ersten Betreten freigeschaltet wird

## Wasserstand über der Ausgangshöhe (setzt z. B. rising_water.gd, wenn das Wasser steigt)
var water_offset: float = 0.0

@onready var _stand_area: Area3D = $StandArea

var _rest_y := 0.0
var _sunk := 0.0


func _ready() -> void:
	_rest_y = position.y


func _physics_process(delta: float) -> void:
	if _player_on_top():
		GameState.unlock_note(note_id)
		_sunk = move_toward(_sunk, sink_depth, sink_speed * delta)
	else:
		_sunk = move_toward(_sunk, 0.0, rise_speed * delta)
	position.y = _rest_y + water_offset - _sunk


func _player_on_top() -> bool:
	for body in _stand_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false
