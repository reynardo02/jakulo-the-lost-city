extends Node3D
## Entfernt beim Start alle Kollisionen aus den Modellen unter diesem Knoten.
## Für .glb-Modelle mit eingebauter Kollision, die an beweglichen Körpern hängen
## (Treibholz, Flöße, umfallender Baumstamm) – dort übernimmt eine eigene Form die Kollision.


func _ready() -> void:
	for body in find_children("*", "StaticBody3D", true, false):
		body.queue_free()
