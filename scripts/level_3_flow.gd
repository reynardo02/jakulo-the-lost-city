extends Node
## Ablauf von Level 3 (Sumpf und der große Baum). Hängt als Knoten "Ablauf" im Level.
##
## 1. Betritt der Spieler die Lichtung (ClearingTrigger), läuft die Flut-Cutscene: Eine Wache
##    legt am Rand der Lichtung einen Hebel um, die Schleuse öffnet sich. Danach gilt der
##    Checkpoint "l3_flut" und das Wasser (rising_water.gd) beginnt zu steigen.
## 2. Oben in der Krone legt der Spieler den Hebel um (CrownLever): Das Wasser sinkt, die
##    Abschluss-Cutscene zeigt den Dorfbewohner aus Level 2 am Fuß des Baums und den
##    freigespülten Höhleneingang. Danach übernimmt der Spieler am Baumfuß.
##
## Der Zustand hängt am Checkpoint, damit er nach einem Tod (Level lädt neu) stimmt:
## Ab "l3_flut" ist die Schleuse offen und die Cutscene läuft nicht noch einmal,
## bei "l3_ende" ist die Flut gestoppt. Alte Abstiegs-Checkpoints werden migriert.
## Hat der Spieler den Dorfbewohner in Level 2 befreit (Flag "villager_freed"), ist er am Ende
## freundlicher. Optional kann er beim Aufstieg mit einer Liane helfen (helper_vine, helper_area).

const FLOOD_CHECKPOINT := "l3_flut"
const FLOODED_CHECKPOINTS := ["l3_flut", "l3_wurzeln", "l3_stamm", "l3_krone"]
const END_CHECKPOINT := "l3_ende"
const LEGACY_DESCENT_CHECKPOINT := "l3_abstieg"
const DONE_FLAG := "l3_flood_stopped"
const FREED_FLAG := "villager_freed"

@export var water: NodePath
@export var clearing_trigger: NodePath
@export var flood_cutscene: NodePath
@export var end_cutscene: NodePath
@export var guard: NodePath             ## Wache am Schleusenhebel
@export var sluice_lever: NodePath      ## lever.gd am Rand der Lichtung
@export var sluice_gate: NodePath       ## Schleusentor (fährt nach oben)
@export var sluice_water: NodePath      ## Wasserfall aus der Schleuse (erst sichtbar, wenn offen)
@export var crown_lever: NodePath       ## lever.gd oben in der Krone
@export var villager: NodePath
@export var cave_block: NodePath        ## Schlamm vor dem Höhleneingang
@export var helper_vine: NodePath
@export var helper_area: NodePath       ## hier ruft der Dorfbewohner beim Aufstieg
@export var flood_spawn: NodePath       ## Marker3D: Startpunkt nach der Flut-Cutscene
@export var end_spawn: NodePath         ## Marker3D: Startpunkt nach dem Abschluss

var _sluice_open := false
var _ended := false
var _gate_closed_y := 0.0
var _gate_tween: Tween


func _ready() -> void:
	_gate_closed_y = (get_node(sluice_gate) as Node3D).position.y
	var checkpoint := GameState.checkpoint_id
	var done := checkpoint in [END_CHECKPOINT, LEGACY_DESCENT_CHECKPOINT]
	if not done:
		GameState.set_flag(DONE_FLAG, false)   # z. B. beim erneuten Spielen des Levels
	if checkpoint in FLOODED_CHECKPOINTS or done:
		_open_sluice_now()
	else:
		(get_node(clearing_trigger) as Area3D).body_entered.connect(_on_clearing_entered)
	if done:
		_show_ending_state()
		(get_node(crown_lever) as Node).call("pull", false)
		(get_node(water) as Node).call("drain_now")
		if checkpoint == LEGACY_DESCENT_CHECKPOINT:
			_on_end_cutscene_finished.call_deferred()
	else:
		(get_node(villager) as Node3D).hide()
		(get_node(crown_lever) as Node).connect("pulled", _on_crown_lever_pulled)

	var freed := GameState.has_flag(FREED_FLAG)
	var vine := get_node_or_null(helper_vine)
	if vine and not freed:
		vine.queue_free()
	var area := get_node_or_null(helper_area) as Area3D
	if area and freed and not done:
		area.body_entered.connect(_on_helper_area_entered)
	_play_villager_idle()


# ---------- Flut ----------

func _on_clearing_entered(body: Node3D) -> void:
	if _sluice_open or not body.is_in_group("player"):
		return
	_sluice_open = true   # Trigger nur einmal
	GameState.unlock_note("big_tree")
	var cutscene := get_node(flood_cutscene)
	cutscene.finished.connect(_on_flood_cutscene_finished, CONNECT_ONE_SHOT)
	cutscene.play()


## Methoden-Spur der Flut-Cutscene: Die Wache legt den Hebel um.
func pull_sluice_lever() -> void:
	(get_node(sluice_lever) as Node).call("pull")


## Methoden-Spur der Flut-Cutscene: Das Tor fährt hoch, das Wasser schießt herein.
func open_sluice() -> void:
	var gate := get_node(sluice_gate) as Node3D
	if gate.has_meta("opened"):
		return
	gate.set_meta("opened", true)
	create_tween().tween_property(gate, "position:y", gate.position.y + 3.4, 1.2) \
		.set_trans(Tween.TRANS_SINE)
	var fall := get_node(sluice_water) as Node3D
	fall.show()
	fall.scale = Vector3(1, 0.05, 1)
	create_tween().tween_property(fall, "scale", Vector3.ONE, 0.8)


## Methoden-Spur der Flut-Cutscene: Die Wache läuft davon.
func guard_leave() -> void:
	var g := get_node(guard) as Node3D
	var tween := create_tween()
	tween.tween_property(g, "rotation:y", 0.0, 0.3)
	tween.tween_property(g, "position", g.position + Vector3(1.5, 0, 9.0), 3.0)
	tween.tween_callback(g.hide)
	_play_animation(g, &"Walk")


func _on_flood_cutscene_finished() -> void:
	_open_sluice_now()
	GameState.set_checkpoint(FLOOD_CHECKPOINT, (get_node(flood_spawn) as Node3D).global_position)
	GameState.flash_message("Das Wasser steigt!\nSchnell zum großen Baum!", 3.5)


## Endzustand der Flut-Cutscene ohne Animation (nach dem Überspringen oder einem Neustart).
func _open_sluice_now() -> void:
	_sluice_open = true
	(get_node(sluice_lever) as Node).call("pull", false)
	var gate := get_node(sluice_gate) as Node3D
	if not gate.has_meta("opened"):
		gate.set_meta("opened", true)
		gate.position.y += 3.4
	var fall := get_node(sluice_water) as Node3D
	fall.show()
	fall.scale = Vector3.ONE
	(get_node(guard) as Node3D).hide()


# ---------- Aufstieg ----------

func _on_helper_area_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	(get_node(helper_area) as Area3D).body_entered.disconnect(_on_helper_area_entered)
	GameState.flash_message("„Fremder! Hier oben – nimm die Liane!“\nDer Dorfbewohner aus dem Dorf hilft dir.", 4.0)


# ---------- Abschluss ----------

func _on_crown_lever_pulled() -> void:
	if _ended:
		return
	_ended = true
	GameState.set_flag(DONE_FLAG)
	var gate := get_node(sluice_gate) as Node3D
	_gate_tween = create_tween()
	_gate_tween.tween_property(gate, "position:y", _gate_closed_y, 1.4)
	(get_node(sluice_water) as Node3D).hide()
	(get_node(water) as Node).call("recede")
	var cutscene := get_node(end_cutscene)
	cutscene.finished.connect(_on_end_cutscene_finished, CONNECT_ONE_SHOT)
	cutscene.play()


## Methoden-Spur der Abschluss-Cutscene: Schnitt nach unten. Wasser weg, Dorfbewohner da,
## Höhle frei. Der Spieler wird während des Kameraschnitts zum Baumfuß versetzt.
func show_ending() -> void:
	(get_node(water) as Node).call("drain_now")
	_show_ending_state()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var spawn := get_node(end_spawn) as Node3D
	if player:
		if player.get("current_vine") != null:
			player.current_vine.detach()
			player.current_vine = null
		player.global_position = spawn.global_position
		player.rotation.y = spawn.global_rotation.y
		player.velocity = Vector3.ZERO
		player.air_momentum = Vector3.ZERO
		player.jump_time = -1.0
		player.get_node("CameraPivot").rotation.y = 0.0
		player.get_node("visuals").global_rotation.y = spawn.global_rotation.y


## Methoden-Spur der Abschluss-Cutscene: Zeile `index` des Dorfbewohners. Der Text hängt
## davon ab, ob der Spieler ihn in Level 2 befreit hat.
func villager_say(index: int) -> void:
	var freed := GameState.has_flag(FREED_FLAG)
	var lines: Array = [
		"Du hast mich im Dorf befreit – und ich halte mein Wort." if freed
			else "Du … du hast mich im Käfig sitzen lassen. Ich kam auch allein heraus.",
		"Das Wasser hat zwischen den Wurzeln einen alten Gang freigespült." if freed
			else "Trotzdem: Zwischen den Wurzeln liegt jetzt ein Gang frei.",
		"Er führt tief unter den Dschungel. Dort beginnt der Weg zur Stadt. Viel Glück!" if freed
			else "Geh schon. Was dich da unten erwartet, ist nicht mehr meine Sache.",
	]
	var cutscene := get_node(end_cutscene)
	if index >= 0 and index < lines.size():
		cutscene.call("say", "Dorfbewohner", lines[index])


func _on_end_cutscene_finished() -> void:
	show_ending()
	GameState.set_checkpoint(END_CHECKPOINT, (get_node(end_spawn) as Node3D).global_position)
	GameState.flash_message("Der Höhleneingang ist frei.", 3.0)


func _show_ending_state() -> void:
	GameState.set_flag(DONE_FLAG)
	if _gate_tween:
		_gate_tween.kill()
	(get_node(sluice_gate) as Node3D).position.y = _gate_closed_y
	(get_node(sluice_water) as Node3D).hide()
	(get_node(villager) as Node3D).show()
	var block := get_node_or_null(cave_block) as Node3D
	if block:
		block.queue_free()


func _play_villager_idle() -> void:
	_play_animation(get_node(villager) as Node3D, &"Idle")


func _play_animation(model: Node3D, animation: StringName) -> void:
	for p in model.find_children("*", "AnimationPlayer", true, false):
		var anim := p as AnimationPlayer
		if anim.has_animation(animation):
			anim.get_animation(animation).loop_mode = Animation.LOOP_LINEAR
			anim.play(animation)
		return
