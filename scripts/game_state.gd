extends Node
## Spielstand über alle Level hinweg (Autoload "GameState").
## Hält Leben, Münzen und Punkte, zeigt sie im HUD an und übernimmt
## Tod (Leben abziehen, Level neu laden) und Levelwechsel.

signal lives_changed(lives: int)
signal coins_changed(coins: int)
signal score_changed(score: int)

const MAX_LIVES := 3
const FIRST_LEVEL := "res://scenes/level_1.tscn"
const COIN_SCORE := 100
const LEVEL_SCORE := 1000

var lives: int = MAX_LIVES
var coins: int = 0
var score: int = 0

# Stand beim Betreten des Levels: Nach einem Tod liegen die Münzen wieder im Level,
# also zählt nur, was man vor diesem Level schon hatte.
var _level_start_coins: int = 0
var _level_start_score: int = 0
var _transitioning := false

var _hud_label: Label
var _message_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_update_hud()


# ---------- Spielstand ----------

func add_coin(amount: int = 1) -> void:
	coins += amount
	score += COIN_SCORE * amount
	coins_changed.emit(coins)
	score_changed.emit(score)
	_update_hud()


func reset() -> void:
	lives = MAX_LIVES
	coins = 0
	score = 0
	_level_start_coins = 0
	_level_start_score = 0
	lives_changed.emit(lives)
	coins_changed.emit(coins)
	score_changed.emit(score)
	_update_hud()


# ---------- Tod ----------

## Spieler ist gestorben: ein Leben weniger, Level neu laden.
## Ohne Leben: Game Over und Neustart bei Level 1.
func player_died(player: Node3D = null, delay: float = 0.5) -> void:
	if _transitioning:
		return
	_transitioning = true
	_freeze(player)

	lives -= 1
	lives_changed.emit(lives)
	coins = _level_start_coins
	score = _level_start_score
	_update_hud()

	if lives <= 0:
		_show_message("Game Over")
		await get_tree().create_timer(maxf(delay, 2.0)).timeout
		reset()
		get_tree().change_scene_to_file(FIRST_LEVEL)
	else:
		await get_tree().create_timer(delay).timeout
		get_tree().reload_current_scene()

	_show_message("")
	_transitioning = false


# ---------- Levelwechsel ----------

## Level geschafft (Portal). next_scene leer = es gibt noch kein Folgelevel:
## Dann startet das Spiel mit frischem Spielstand wieder bei Level 1.
func level_completed(player: Node3D = null, next_scene: String = "", delay: float = 2.0) -> void:
	if _transitioning:
		return
	_transitioning = true
	_freeze(player)

	score += LEVEL_SCORE
	score_changed.emit(score)
	_update_hud()

	var has_next := next_scene != "" and ResourceLoader.exists(next_scene)
	_show_message("Level geschafft!" if has_next else "Level geschafft!\nWeitere Level folgen …")
	await get_tree().create_timer(delay).timeout

	if has_next:
		_level_start_coins = coins
		_level_start_score = score
		get_tree().change_scene_to_file(next_scene)
	else:
		reset()
		get_tree().change_scene_to_file(FIRST_LEVEL)

	_show_message("")
	_transitioning = false


func _freeze(player: Node3D) -> void:
	if player == null or not is_instance_valid(player):
		return
	player.set_physics_process(false)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO


# ---------- HUD ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	layer.layer = 10
	add_child(layer)

	_hud_label = Label.new()
	_hud_label.position = Vector2(24, 16)
	_hud_label.add_theme_font_size_override("font_size", 28)
	_hud_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_hud_label)

	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 64)
	_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_message_label.add_theme_constant_override("outline_size", 14)
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_message_label)


func _update_hud() -> void:
	if _hud_label:
		_hud_label.text = "Leben: %d    Münzen: %d    Punkte: %d" % [maxi(lives, 0), coins, score]


## Zeigt einen Hinweis in der Bildschirmmitte ("" blendet ihn aus).
func show_message(text: String) -> void:
	if not _transitioning:
		_show_message(text)


func _show_message(text: String) -> void:
	if _message_label:
		_message_label.text = text
