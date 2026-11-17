extends Node3D
## Tier, das den Weg versperrt (Affe, Papagei). Solange es da ist, hält eine unsichtbare Wand
## (Blocker) den Spieler auf. Mit flee() ergreift es die Flucht und gibt den Weg frei.
## Mit `direct_hit` ist es selbst ein Ziel der Schlinge (Papagei); sonst muss man es auf
## anderem Weg vertreiben, z. B. über ein Wespennest (Affe, siehe wasp_nest.gd).
##
## Aufbau: Model (Node3D), Blocker (StaticBody3D), Sight (Area3D: Spieler kommt in Sichtweite).

@export var direct_hit: bool = true
@export var note_id: String = ""            ## Notiz beim ersten Anblick
@export_multiline var blocked_hint: String = ""   ## Hinweis, wenn der Spieler davorsteht
@export var flee_offset: Vector3 = Vector3(0, 7, -10)   ## Fluchtweg (lokal)
@export var flee_time: float = 1.6
@export var hop_height: float = 0.12        ## Hüpfen im Stand
@export var hop_speed: float = 5.0

@onready var _model: Node3D = $Model
@onready var _blocker: StaticBody3D = $Blocker
@onready var _sight: Area3D = $Sight

var _fled := false
var _t := 0.0
var _rest := Vector3.ZERO


func _ready() -> void:
	_rest = _model.position
	if direct_hit:
		add_to_group("sling_target")
	_sight.body_entered.connect(_on_sight_entered)


func _process(delta: float) -> void:
	if _fled:
		return
	_t += delta
	_model.position.y = _rest.y + absf(sin(_t * hop_speed)) * hop_height


func can_be_hit() -> bool:
	return not _fled


func get_sling_point() -> Vector3:
	return _model.global_position + Vector3.UP * 0.4


func sling_hit() -> void:
	flee()


func flee() -> void:
	if _fled:
		return
	_fled = true
	remove_from_group("sling_target")
	for shape in _blocker.get_children():
		if shape is CollisionShape3D:
			(shape as CollisionShape3D).set_deferred("disabled", true)
	# alle Tiere der Gruppe fliehen (Model, Model2, …) und verschwinden danach ganz
	var tween := create_tween().set_parallel()
	var animals: Array[Node3D] = []
	for child in get_children():
		if child is Node3D and String(child.name).begins_with("Model"):
			animals.append(child)
	for i in animals.size():
		var animal := animals[i]
		var offset := flee_offset + Vector3(randf_range(-1.5, 1.5), i * 0.8, randf_range(-1.5, 1.5))
		tween.tween_property(animal, "position", animal.position + offset, flee_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(i * 0.15)
		if animal.has_method("play_anim"):
			# geriggter Affe: in Fluchtrichtung drehen und davonrennen
			animal.rotation.y = atan2(offset.x, offset.z)
			animal.play_anim(&"running", 0.15, 1.4)
			tween.tween_property(animal, "scale", animal.scale * 0.6, flee_time).set_delay(i * 0.15)
		else:
			tween.tween_property(animal, "rotation:y", animal.rotation.y + TAU, flee_time).set_delay(i * 0.15)
			tween.tween_property(animal, "scale", animal.scale * 0.2, flee_time).set_delay(i * 0.15)
	tween.chain().tween_callback(func() -> void:
		for animal in animals:
			animal.hide())


func _on_sight_entered(body: Node3D) -> void:
	if _fled or not body.is_in_group("player"):
		return
	if note_id != "":
		GameState.unlock_note(note_id)
	if blocked_hint != "":
		GameState.flash_message(blocked_hint.replace("{sling}", GameState.action_label("sling")), 3.0)
