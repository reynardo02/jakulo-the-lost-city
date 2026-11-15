extends Area3D
## Gegenstand zum Aufsammeln: Läuft der Spieler hinein, landet er im Inventar (GameState.items).
## Mit `once` liegt er nicht noch einmal da, wenn man ihn schon besitzt (z. B. nach einem Tod).
## Mit `required_flag` erscheint er erst, wenn das Flag im GameState gesetzt ist.

@export var item_id: String = ""
@export var amount: int = 1
@export var message: String = ""   ## Hinweis beim Aufsammeln ("" = keiner)
@export var once: bool = true
@export var required_flag: String = ""   ## z. B. "villager_freed"; leer = liegt von Anfang an da
@export var spin_speed: float = 1.2   ## rad/s, dreht das Modell zur besseren Sichtbarkeit


func _ready() -> void:
	if once and GameState.has_item(item_id):
		queue_free()
		return
	body_entered.connect(_on_body_entered)
	GameState.flag_set.connect(_on_flag_set)
	_update_available()


func _process(delta: float) -> void:
	rotate_y(spin_speed * delta)


func is_available() -> bool:
	return required_flag == "" or GameState.has_flag(required_flag)


func _update_available() -> void:
	visible = is_available()
	set_deferred("monitoring", is_available())


func _on_flag_set(id: String) -> void:
	if id == required_flag:
		_update_available()


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not is_available():
		return
	GameState.add_item(item_id, amount)
	if message != "":
		GameState.flash_message(message, 3.0)
	queue_free()
