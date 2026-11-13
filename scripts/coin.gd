extends Area3D
@export var rotation_speed =2.0
signal coin
var collected=false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	rotate_y(rotation_speed*delta)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and collected==false:
		collected=true;
		$coin/Mesh.hide()
		$CollisionShape3D.set_deferred("disabled",true)
		GameState.add_coin()
		$Sound.play()
		await $Sound.finished
		coin.emit()
		queue_free()
