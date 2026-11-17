extends CanvasLayer
## Das alte Buch (Autoload "Book").
## Wird an der Ruine in Level 1 gefunden und danach jederzeit mit "open_book" (B)
## geöffnet. Seiten: Mission, Karte, Notizen, Erfolge & Inventar.
## Solange das Buch offen ist, ist das Spiel pausiert.

signal opened
signal closed

const PAPER := Color(0.93, 0.86, 0.7)
const PAPER_DARK := Color(0.83, 0.74, 0.56)
const INK := Color(0.24, 0.15, 0.08)
const INK_FADED := Color(0.24, 0.15, 0.08, 0.45)
const GOLD := Color(0.85, 0.62, 0.15)

## Anzeigenamen für Items im Inventar (Fallback: die Item-ID)
const ITEM_NAMES := {
	"water_bottle": "Trinkflasche",
	"sling": "Schlinge",
	"jewel": "Juwel",
}

const MISSION_TEXT := """[font_size=26][b]Die Lost City[/b][/font_size]
Wer dieses Buch findet, ist weiter gekommen als die meisten. Tief im Dschungel, jenseits der Dörfer, unter den Höhlen und hinter den Tempeln, liegt die [b]verlorene Stadt[/b]. Seit Jahrhunderten hat sie niemand mehr betreten.
Das Portal in dieser Ruine öffnet den Weg. Jeder Abschnitt der Reise ist gefährlicher als der vorige.

[font_size=22][b]Missionsziele[/b][/font_size]
"""

const CONTROLS_TEXT := """[font_size=22][b]Tastatur und Maus[/b][/font_size]
Laufen: W A D und Pfeiltasten
Kamera: Maus
Springen, Liane loslassen, aus dem Maul befreien: Leertaste
Weiter Sprung: im Laufen zweimal Leertaste
An der Liane klettern: Pfeil runter / W
Schleichen an/aus: Strg oder C
Benutzen: E          Buch: B
Schlinge: F oder linke Maustaste halten = zielen, loslassen = schießen

[font_size=22][b]PS5-Controller[/b][/font_size]
Laufen: linker Stick oder Steuerkreuz
Kamera: rechter Stick
Springen, Liane loslassen, aus dem Maul befreien: Kreuz
Weiter Sprung: im Laufen zweimal Kreuz
An der Liane klettern: linker Stick runter / hoch
Schleichen an/aus: Kreis
Benutzen: Quadrat          Buch: Dreieck
Schlinge: R2 halten = zielen, loslassen = schießen
Im Buch: L1 / R1 blättern, Kreis schließen
"""

var is_open := false

var _root: Control
var _tabs: TabContainer
var _mission_goals: RichTextLabel
var _map: MapView
var _map_info: Label
var _notes_text: RichTextLabel
var _inventory_text: RichTextLabel
var _close_button: Button
var _footer: Label
var _mouse_mode_before := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func _unhandled_input(event: InputEvent) -> void:
	if is_open:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("book_close") \
				or event.is_action_pressed("open_book") \
				or event.is_action_pressed("interact"):
			close()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_left") or event.is_action_pressed("book_prev"):
			_tabs.current_tab = wrapi(_tabs.current_tab - 1, 0, _tabs.get_tab_count())
		elif event.is_action_pressed("move_right") or event.is_action_pressed("book_next"):
			_tabs.current_tab = wrapi(_tabs.current_tab + 1, 0, _tabs.get_tab_count())
	elif event.is_action_pressed("open_book") and GameState.has_flag("book_found") \
			and not get_tree().paused:
		open()
		get_viewport().set_input_as_handled()


func open(tab: int = -1) -> void:
	if is_open:
		return
	is_open = true
	_refresh()
	if tab >= 0:
		_tabs.current_tab = tab
	_root.show()
	_mouse_mode_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.hide()
	GameState.mark_notes_read()
	get_tree().paused = false
	Input.mouse_mode = _mouse_mode_before
	closed.emit()


# ---------- Inhalt ----------

func _refresh() -> void:
	_update_key_hints()
	_mission_goals.text = _goals_text()
	_map.queue_redraw()
	_map_info.text = _map_info_text()
	_notes_text.text = _notes_bbcode()
	_inventory_text.text = _inventory_bbcode()


func _goals_text() -> String:
	var level_1_done := GameState.is_level_unlocked("level_2")
	var goals := [
		["Den Dschungelpfad durchqueren", GameState.has_flag("book_found") or level_1_done],
		["Das alte Buch in der Ruine finden", GameState.has_flag("book_found")],
		["Durch das Portal reisen", level_1_done],
		["Die Lost City erreichen", false],
	]
	var text := ""
	for g in goals:
		text += "%s  %s\n" % ["[color=#2f6b1f]☑[/color]" if g[1] else "☐", g[0]]
	return MISSION_TEXT + text


func _map_info_text() -> String:
	var current := GameState.current_level_index()
	if current < 0:
		return ""
	var level: Dictionary = GameState.LEVELS[current]
	return "Du bist hier: %s\n%s" % [level.name, level.description]


func _notes_bbcode() -> String:
	if GameState.notes.is_empty():
		return "[i]Noch keine Notizen. Was du unterwegs über Tiere, Ureinwohner und Orte herausfindest, wird hier festgehalten.[/i]"
	var text := ""
	for id in GameState.notes:
		var note: Dictionary = GameState.NOTES[id]
		var badge := "  [color=#b8860b][b]NEU[/b][/color]" if GameState.is_note_unread(id) else ""
		text += "[font_size=22][b]%s[/b][/font_size]%s\n%s\n\n" % [note.title, badge, note.text]
	return text


func _inventory_bbcode() -> String:
	var text := "[font_size=22][b]Ausrüstung[/b][/font_size]\n"
	text += "Leben: %d / %d\nMünzen: %d\nPunkte: %d\n" % [
		GameState.lives, GameState.MAX_LIVES, GameState.coins, GameState.score]
	if GameState.items.is_empty():
		text += "[i]Noch keine Gegenstände.[/i]\n"
	else:
		for id in GameState.items:
			text += "%s × %d\n" % [ITEM_NAMES.get(id, id), GameState.items[id]]
	text += "\n[font_size=22][b]Erfolge[/b][/font_size]\n[i]Folgen später.[/i]"
	return text


# ---------- Aufbau ----------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = _make_theme()
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var book := PanelContainer.new()
	book.custom_minimum_size = Vector2(900, 560)
	center.add_child(book)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	book.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "Das alte Buch"
	title.add_theme_font_size_override("font_size", 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close_button = Button.new()
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.focus_mode = Control.FOCUS_NONE
	vbox.add_child(_tabs)

	_mission_goals = _add_text_page("Mission")

	var map_page := VBoxContainer.new()
	map_page.name = "Karte"
	_tabs.add_child(map_page)
	_map = MapView.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_page.add_child(_map)
	_map_info = Label.new()
	_map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_page.add_child(_map_info)

	_notes_text = _add_text_page("Notizen")
	_inventory_text = _add_text_page("Erfolge & Inventar")
	_add_text_page("Steuerung").text = CONTROLS_TEXT

	_footer = Label.new()
	_footer.add_theme_color_override("font_color", INK_FADED)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_footer)
	_update_key_hints()
	GameState.input_device_changed.connect(func(_gamepad: bool) -> void: _update_key_hints())


## Beschriftungen passend zum zuletzt benutzten Eingabegerät (Tastatur oder Controller).
func _update_key_hints() -> void:
	_close_button.text = "Schließen (%s)" % GameState.action_label("close")
	_footer.text = "%s: Seite wechseln     %s: Buch öffnen und schließen" % [
		GameState.action_label("pages"), GameState.action_label("open_book")]


func _add_text_page(page_name: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.name = page_name
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = true
	_tabs.add_child(label)
	return label


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 19

	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER
	paper.border_color = Color(0.45, 0.27, 0.12)
	paper.set_border_width_all(10)
	paper.set_corner_radius_all(12)
	paper.set_content_margin_all(22)
	theme.set_stylebox("panel", "PanelContainer", paper)

	var page := StyleBoxFlat.new()
	page.bg_color = PAPER
	page.border_color = PAPER_DARK
	page.set_border_width_all(2)
	page.set_content_margin_all(18)
	theme.set_stylebox("panel", "TabContainer", page)

	var tab_selected := StyleBoxFlat.new()
	tab_selected.bg_color = PAPER
	tab_selected.border_color = PAPER_DARK
	tab_selected.set_border_width_all(2)
	tab_selected.border_width_bottom = 0
	tab_selected.set_corner_radius_all(6)
	tab_selected.set_content_margin_all(10)
	var tab_unselected := tab_selected.duplicate() as StyleBoxFlat
	tab_unselected.bg_color = PAPER_DARK
	theme.set_stylebox("tab_selected", "TabContainer", tab_selected)
	theme.set_stylebox("tab_unselected", "TabContainer", tab_unselected)
	theme.set_stylebox("tab_hovered", "TabContainer", tab_unselected)
	theme.set_color("font_selected_color", "TabContainer", INK)
	theme.set_color("font_unselected_color", "TabContainer", INK_FADED)
	theme.set_color("font_hovered_color", "TabContainer", INK)

	var button := StyleBoxFlat.new()
	button.bg_color = PAPER_DARK
	button.set_corner_radius_all(6)
	button.set_content_margin_all(8)
	theme.set_stylebox("normal", "Button", button)
	theme.set_stylebox("hover", "Button", button)
	theme.set_stylebox("pressed", "Button", button)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)

	theme.set_color("font_color", "Label", INK)
	theme.set_color("default_color", "RichTextLabel", INK)
	return theme


## Karte der Reise: ein gewundener Pfad mit einer Station pro Level.
class MapView extends Control:
	func _draw() -> void:
		var levels := GameState.LEVELS
		var current := GameState.current_level_index()
		var font := get_theme_default_font()
		var points: Array[Vector2] = []
		for i in levels.size():
			var t := float(i) / maxf(levels.size() - 1, 1)
			var x := lerpf(70.0, size.x - 70.0, t)
			var y := size.y * (0.4 if i % 2 == 0 else 0.65)
			points.append(Vector2(x, y))

		# Pfad gestrichelt, bis zum letzten freigeschalteten Level durchgezogen
		for i in points.size() - 1:
			var unlocked := GameState.is_level_unlocked(levels[i + 1].id)
			if unlocked:
				draw_line(points[i], points[i + 1], INK, 4.0, true)
			else:
				draw_dashed_line(points[i], points[i + 1], INK_FADED, 3.0, 12.0)

		for i in points.size():
			var unlocked := GameState.is_level_unlocked(levels[i].id)
			var p := points[i]
			if i == current:
				draw_circle(p, 30.0, GOLD, false, 4.0, true)
			draw_circle(p, 20.0, GOLD if unlocked else PAPER_DARK)
			draw_circle(p, 20.0, INK, false, 2.0, true)
			var number := str(i + 1)
			var num_size := font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
			draw_string(font, p + Vector2(-num_size.x / 2.0, 8.0), number,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)

			var label: String = levels[i].name if unlocked else "???"
			var label_y := -44.0 if i % 2 == 0 else 58.0
			draw_string(font, p + Vector2(-90.0, label_y), label, HORIZONTAL_ALIGNMENT_CENTER,
				180.0, 18, INK if unlocked else INK_FADED)
