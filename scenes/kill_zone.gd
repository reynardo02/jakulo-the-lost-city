extends Area3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_body_entered(body: Node3D):
	if body.name == "Player":
		body.set_physics_process(false)
		(body as CharacterBody3D).velocity = Vector3.ZERO
		await  get_tree().create_timer(0.5).timeout
	
		get_tree().reload_current_scene()
