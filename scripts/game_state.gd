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
signal input_device_changed(gamepad: bool)

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
		"scene": "res://scenes/level_2.tscn",
		"description": "Mehr Krokodile und ein Dorf feindlicher Ureinwohner. Hier hilft nur Schleichen.",
	},
	{
		"id": "level_3",
		"name": "Sumpf und der große Baum",
		"scene": "res://scenes/level_3.tscn",
		"description": "Schlafende Affen im Sumpf, dann eine Flut – und ein Baum, der höher ist als alles Wasser.",
	},
	{
		"id": "level_4",
		"name": "Die Höhlen",
		"scene": "",
		"description": "Unterirdische Tunnel in völliger Dunkelheit. Eine Fackel wäre hilfreich.",
	},
	{
		"id": "level_5",
		"name": "Die verlassene Mine",
		"scene": "",
		"description": "Verschüttete Gänge, die sich nur freisprengen lassen.",
	},
	{
		"id": "level_6",
		"name": "Der Bergpass",
		"scene": "",
		"description": "Eiswände und Gletscher – dahinter der erste Blick auf die Lost City.",
	},
	{
		"id": "level_7",
		"name": "Die Tempelruinen",
		"scene": "",
		"description": "Der Eingang zur Lost City, gesichert mit Fallen und Rätseln.",
	},
	{
		"id": "level_8",
		"name": "Die verlorene Stadt",
		"scene": "",
		"description": "Das weite Herz der Lost City.",
	},
	{
		"id": "level_9",
		"name": "Das Finale",
		"scene": "",
		"description": "Der Wächter der Stadt und die Entscheidung über das Artefakt.",
	},
]

## Texte der Notizen im Buch. Freigeschaltet werden sie über unlock_note(), sobald der
## Spieler etwas zum ersten Mal trifft: Krokodil und Liane melden sich selbst (Export
## `note_id`), für alles andere gibt es scenes/note_trigger.tscn.
## Neue Notiz = neuer Eintrag hier plus ein Auslöser mit derselben ID.
const NOTES := {
	"vine": {
		"title": "Lianen",
		"text": "Hängen über Gruben und Wasser. Im Sprung greift man sie von selbst, schwingt hinüber und lässt mit SPRINGEN wieder los. Am meisten Schwung hat man am vorderen Umkehrpunkt. Mit ZURÜCK klettert man an der Liane nach unten und schwingt dann weiter aus, mit VOR wieder nach oben.",
	},
	"crocodile": {
		"title": "Krokodile",
		"text": "Liegen reglos im Wasser und eignen sich als Trittsteine. Berührt man sie, zucken sie kurz und reißen dann das Maul auf. Wer gepackt wird, muss sich mit aller Kraft befreien (SPRINGEN).",
	},
	"natives": {
		"title": "Die Wachen im Dorf",
		"text": "Sie sehen nur, was vor ihnen liegt – der helle Kegel am Boden zeigt ihr Blickfeld. Wer schleicht, wird langsamer entdeckt und nicht gehört. Geduckt im hohen Gras ist man unsichtbar, solange man ihnen nicht direkt vor die Füße läuft.",
	},
	"lily_pad": {
		"title": "Seerosen",
		"text": "Tragen einen Menschen nur für einen Augenblick. Wer stehen bleibt, versinkt mit ihnen im Wasser – also zügig von Blatt zu Blatt springen.",
	},
	"sling": {
		"title": "Die Schlinge",
		"text": "Trifft, was man mit der Hand nicht erreicht. Ziele in Reichweite tragen einen goldenen Ring. Zum Zielen F, die linke Maustaste oder R2 gedrückt halten – das Fadenkreuz wird golden, wenn es auf einem Ziel liegt. Loslassen schießt. Sie durchtrennt Seile, verscheucht Tiere und lässt ein Krokodil für ein paar Sekunden das Maul geschlossen halten.",
	},
	"monkey": {
		"title": "Affen",
		"text": "Schlafen am liebsten am Wasser und haben ein feines Gehör. Wer aufrecht an ihnen vorbeiläuft, ins flache Wasser platscht oder auf einen hellen, trockenen Ast tritt, weckt sie – und dann fliegen Früchte. Geduckt schleichen, über trockene Äste springen. Ein Wespennest über ihrem Kopf vertreibt sie ganz.",
	},
	"big_tree": {
		"title": "Der große Baum",
		"text": "Der älteste Baum des Dschungels steht mitten auf einer Lichtung, die sich mit Schleusen fluten lässt. Jemand hat Plattformen und Stege in seinen Stamm gebaut – und ganz oben in der Krone einen Hebel, der die Schleusen wieder schließt.",
	},
	"driftwood": {
		"title": "Treibholz",
		"text": "Treibt auf dem Wasser hin und her und trägt einen Menschen. Am besten aufspringen, wenn es gerade am nächsten ist, und mitfahren.",
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

## true, sobald zuletzt ein Controller benutzt wurde - Hinweise zeigen dann dessen Tasten.
var using_gamepad := false

## Anzeigenamen der Tasten je Aktion: [Tastatur, PS5-Controller]
const ACTION_LABELS := {
	"jump": ["LEERTASTE", "KREUZ"],
	"interact": ["E", "QUADRAT"],
	"open_book": ["B", "DREIECK"],
	"close": ["E", "KREIS"],
	"crouch": ["STRG", "KREIS"],
	"pages": ["A / D", "L1 / R1"],
	"sling": ["F", "R2"],
}

var _hud_label: Label
var _status_label: Label
var _detection_bar: ProgressBar
var _detections := {}   # Wache (Instanz-ID) -> Entdeckungsanzeige 0 .. 1
var _player_status := ""
var _message_label: Label
var _flash_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_update_hud()


# ---------- Eingabegerät ----------

func _input(event: InputEvent) -> void:
	var gamepad := using_gamepad
	if event is InputEventJoypadButton:
		gamepad = true
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) < 0.5:
			return   # Stick-Rauschen zählt nicht als Wechsel
		gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		gamepad = false
	if gamepad != using_gamepad:
		using_gamepad = gamepad
		input_device_changed.emit(gamepad)


## Name der Taste für eine Aktion, passend zum zuletzt benutzten Eingabegerät.
func action_label(action: String) -> String:
	var labels: Array = ACTION_LABELS.get(action, [action, action])
	return labels[1] if using_gamepad else labels[0]


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


# ---------- Schleichen und Entdeckung ----------

## Jede Wache meldet hier laufend ihre Entdeckungsanzeige (0 .. 1). Das HUD zeigt die höchste.
func report_detection(source: Object, value: float) -> void:
	if value <= 0.0:
		_detections.erase(source.get_instance_id())
	else:
		_detections[source.get_instance_id()] = value
	var highest := 0.0
	for v in _detections.values():
		highest = maxf(highest, v)
	if _detection_bar:
		_detection_bar.value = highest
		_detection_bar.get_parent().visible = highest > 0.01


## Der Spieler meldet, ob er schleicht oder versteckt ist ("" = normal). Steht unter den Leben.
func set_player_status(text: String) -> void:
	if text == _player_status:
		return
	_player_status = text
	if _status_label:
		_status_label.text = text


## Eine Wache hat den Spieler entdeckt: zurück zum letzten Checkpoint.
## Ohne `costs_life` kostet das kein Leben, nur die im Level gesammelten Münzen sind wieder weg.
func player_caught(player: Node3D = null, costs_life: bool = false, delay: float = 1.5) -> void:
	if costs_life:
		player_died(player, delay)
		return
	if _transitioning:
		return
	_transitioning = true
	_freeze(player)
	coins = _level_start_coins
	score = _level_start_score
	_update_hud()
	_show_message("Entdeckt!")
	await get_tree().create_timer(delay).timeout
	_detections.clear()
	report_detection(self, 0.0)
	get_tree().reload_current_scene()
	_show_message("")
	_transitioning = false


# ---------- Tod ----------

## Ein Treffer, der ein Leben kostet, ohne das Level neu zu laden (z. B. Frucht eines Affen).
## Ist es das letzte Leben, gilt es als Tod.
func hurt(player: Node3D = null, text: String = "Autsch!") -> void:
	if _transitioning:
		return
	if lives <= 1:
		player_died(player)
		return
	lives -= 1
	lives_changed.emit(lives)
	_update_hud()
	flash_message(text, 1.5)


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

	_status_label = Label.new()
	_status_label.position = Vector2(24, 54)
	_status_label.add_theme_font_size_override("font_size", 24)
	_status_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.6))
	_status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_status_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(_status_label)

	# Entdeckungsanzeige: oben in der Mitte, nur sichtbar, solange eine Wache etwas bemerkt
	var detection_box := VBoxContainer.new()
	detection_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	detection_box.position = Vector2(-160, 20)
	detection_box.custom_minimum_size = Vector2(320, 0)
	detection_box.visible = false
	layer.add_child(detection_box)
	var detection_title := Label.new()
	detection_title.text = "Entdeckung"
	detection_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detection_title.add_theme_font_size_override("font_size", 22)
	detection_title.add_theme_color_override("font_outline_color", Color.BLACK)
	detection_title.add_theme_constant_override("outline_size", 8)
	detection_box.add_child(detection_title)
	_detection_bar = ProgressBar.new()
	_detection_bar.max_value = 1.0
	_detection_bar.step = 0.0
	_detection_bar.show_percentage = false
	_detection_bar.custom_minimum_size = Vector2(320, 18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.3, 0.15)
	fill.set_corner_radius_all(4)
	_detection_bar.add_theme_stylebox_override("fill", fill)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.55)
	back.set_corner_radius_all(4)
	_detection_bar.add_theme_stylebox_override("background", back)
	detection_box.add_child(_detection_bar)

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
