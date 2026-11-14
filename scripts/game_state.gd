extends Node
## Spielstand über alle Level hinweg (Autoload "GameState").
## Hält Leben, Münzen, Punkte, Items, Notizen, freigeschaltete Level und den
## letzten Checkpoint, zeigt das HUD an und übernimmt Tod (Leben abziehen,
## am Checkpoint neu starten) und Levelwechsel.

signal lives_changed(lives: int)
signal coins_changed(coins: int)
signal score_changed(score: int)
signal items_changed(items: Dictionary)
signal note_unlocked(id: String)
signal level_unlocked(id: String)
signal checkpoint_changed(id: String)
signal flag_set(id: String)

const MAX_LIVES := 3
const FIRST_LEVEL := "res://scenes/level_1.tscn"
const COIN_SCORE := 100
const LEVEL_SCORE := 1000

## Alle Level der Reise zur Lost City, in Spielreihenfolge.
## "scene" bleibt leer, solange es das Level noch nicht gibt.
const LEVELS: Array[Dictionary] = [
	{
		"id": "level_1",
		"name": "Der Dschungelpfad",
		"scene": "res://scenes/level_1.tscn",
		"description": "Baumstämme, Gruben, Lianen und Krokodile – der Weg zur alten Ruine.",
	},
	{
		"id": "level_2",
		"name": "Das Dorf im Dschungel",
		"scene": "",
		"description": "Feindliche Ureinwohner und wilde Tiere. Hier hilft nur Schleichen.",
	},
	{
		"id": "level_3",
		"name": "Die Höhlen",
		"scene": "",
		"description": "Unterirdische Tunnel in völliger Dunkelheit. Eine Fackel wäre hilfreich.",
	},
	{
		"id": "level_4",
		"name": "Die Tempelruinen",
		"scene": "",
		"description": "Der Eingang zur Lost City, gesichert mit Fallen und Rätseln.",
	},
	{
		"id": "level_5",
		"name": "Die verlorene Stadt",
		"scene": "",
		"description": "Das Herz der Lost City und ihr Wächter.",
	},
]

## Texte der Notizen im Buch. Freigeschaltet werden sie über unlock_note(), sobald der
## Spieler etwas zum ersten Mal trifft: Krokodil und Liane melden sich selbst (Export
## `note_id`), für alles andere gibt es scenes/note_trigger.tscn.
## Neue Notiz = neuer Eintrag hier plus ein Auslöser mit derselben ID.
const NOTES := {
	"vine": {
		"title": "Lianen",
		"text": "Hängen über Gruben und Wasser. Im Sprung greift man sie von selbst, schwingt hinüber und lässt mit SPRINGEN wieder los. Am meisten Schwung hat man am vorderen Umkehrpunkt.",
	},
	"crocodile": {
		"title": "Krokodile",
		"text": "Liegen reglos im Wasser und eignen sich als Trittsteine. Berührt man sie, zucken sie kurz und reißen dann das Maul auf. Wer gepackt wird, muss sich mit aller Kraft befreien (SPRINGEN).",
	},
}

var lives: int = MAX_LIVES
var coins: int = 0
var score: int = 0
var items: Dictionary = {}           # Item-ID -> Anzahl
var notes: Array[String] = []        # freigeschaltete Notiz-IDs, in Fundreihenfolge
var unread_notes: Array[String] = [] # davon noch nicht im Buch gelesen
var unlocked_levels: Array[String] = ["level_1"]
var flags: Dictionary = {}           # einmalige Ereignisse, z. B. "book_read"

# Letzter Checkpoint im aktuellen Level ("" = keiner, Start am Levelanfang)
var checkpoint_id: String = ""
var _checkpoint_position := Vector3.ZERO

# Stand beim Betreten des Levels: Nach einem Tod liegen die Münzen wieder im Level,
# also zählt nur, was man vor diesem Level schon hatte.
var _level_start_coins: int = 0
var _level_start_score: int = 0
var _transitioning := false

var _hud_label: Label
var _message_label: Label
var _flash_id := 0


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


## Füllt Leben auf (z. B. Trinkflasche), höchstens bis MAX_LIVES.
func heal(amount: int = 1) -> void:
	lives = mini(lives + amount, MAX_LIVES)
	lives_changed.emit(lives)
	_update_hud()


func reset() -> void:
	lives = MAX_LIVES
	coins = 0
	score = 0
	items.clear()
	notes.clear()
	unread_notes.clear()
	unlocked_levels = ["level_1"]
	flags.clear()
	_level_start_coins = 0
	_level_start_score = 0
	clear_checkpoint()
	lives_changed.emit(lives)
	coins_changed.emit(coins)
	score_changed.emit(score)
	items_changed.emit(items)
	_update_hud()


# ---------- Items ----------

func add_item(id: String, amount: int = 1) -> void:
	items[id] = get_item_count(id) + amount
	items_changed.emit(items)


func get_item_count(id: String) -> int:
	return items.get(id, 0)


func has_item(id: String) -> bool:
	return get_item_count(id) > 0


## Verbraucht ein Item. Gibt false zurück, wenn keins da ist.
func use_item(id: String, amount: int = 1) -> bool:
	if get_item_count(id) < amount:
		return false
	items[id] -= amount
	if items[id] <= 0:
		items.erase(id)
	items_changed.emit(items)
	return true


# ---------- Notizen ----------

## Schaltet eine Notiz frei. Gibt true zurück, wenn sie neu ist.
func unlock_note(id: String) -> bool:
	if id in notes or not NOTES.has(id):
		return false
	notes.append(id)
	unread_notes.append(id)
	note_unlocked.emit(id)
	# Vor dem Fund des Buchs wird still mitgeschrieben - die Einträge stehen dann schon drin.
	if has_flag("book_found"):
		flash_message("Neue Notiz im Buch: %s" % NOTES[id].title)
	return true


func has_note(id: String) -> bool:
	return id in notes


func is_note_unread(id: String) -> bool:
	return id in unread_notes


## Das Buch ruft das auf, nachdem die Notizen-Seite angezeigt wurde.
func mark_notes_read() -> void:
	unread_notes.clear()


# ---------- Level ----------

func unlock_level(id: String) -> void:
	if id in unlocked_levels:
		return
	unlocked_levels.append(id)
	level_unlocked.emit(id)


func is_level_unlocked(id: String) -> bool:
	return id in unlocked_levels


## Index des gerade geladenen Levels in LEVELS, -1 wenn es keins davon ist.
func current_level_index() -> int:
	var scene := get_tree().current_scene
	if scene == null:
		return -1
	for i in LEVELS.size():
		if LEVELS[i].scene == scene.scene_file_path:
			return i
	return -1


func set_flag(id: String, value: bool = true) -> void:
	if flags.get(id, false) == value:
		return
	flags[id] = value
	flag_set.emit(id)


func has_flag(id: String) -> bool:
	return flags.get(id, false)


# ---------- Checkpoints ----------

## Merkt sich den Checkpoint als Startpunkt nach einem Tod.
## Gibt true zurück, wenn er neu aktiviert wurde.
func set_checkpoint(id: String, spawn_position: Vector3) -> bool:
	if id == checkpoint_id:
		return false
	checkpoint_id = id
	_checkpoint_position = spawn_position
	checkpoint_changed.emit(id)
	return true


func clear_checkpoint() -> void:
	checkpoint_id = ""
	checkpoint_changed.emit("")


func has_checkpoint() -> bool:
	return checkpoint_id != ""


## Wo der Spieler nach dem Laden des Levels startet (nur gültig mit has_checkpoint()).
func get_respawn_position() -> Vector3:
	return _checkpoint_position


# ---------- Tod ----------

## Spieler ist gestorben: ein Leben weniger, Level neu laden – der Spieler startet
## dann am letzten Checkpoint. Ohne Leben: Game Over und Neustart bei Level 1.
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

	var index := current_level_index()
	if index >= 0 and index + 1 < LEVELS.size():
		unlock_level(LEVELS[index + 1].id)

	var has_next := next_scene != "" and ResourceLoader.exists(next_scene)
	_show_message("Level geschafft!" if has_next else "Level geschafft!\nWeitere Level folgen …")
	await get_tree().create_timer(delay).timeout

	clear_checkpoint()
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
	_flash_id += 1
	if not _transitioning:
		_show_message(text)


## Zeigt einen Hinweis für ein paar Sekunden.
func flash_message(text: String, duration: float = 2.0) -> void:
	show_message(text)
	var id := _flash_id
	await get_tree().create_timer(duration).timeout
	# nur ausblenden, wenn inzwischen kein anderer Hinweis kam
	if id == _flash_id:
		show_message("")


func _show_message(text: String) -> void:
	if _message_label:
		_message_label.text = text
