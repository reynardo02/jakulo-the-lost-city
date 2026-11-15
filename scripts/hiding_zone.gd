extends Area3D
## Versteck, z. B. hohes Gras: Wer hier schleicht, ist für Wachen unsichtbar
## (Player.is_hidden()). Die CollisionShape bestimmt die Fläche.


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and "hiding_zones" in body:
		body.hiding_zones += 1


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") and "hiding_zones" in body:
		body.hiding_zones = maxi(body.hiding_zones - 1, 0)
