extends Area3D
## Schaltet eine Notiz im Buch frei, sobald der Spieler den Bereich zum ersten Mal betritt.
## Für alles, was kein eigenes Script mit `note_id` hat: Orte, Ureinwohner, Tiere.
## Als Kind an das Objekt hängen und die CollisionShape so groß ziehen, wie der Spieler
## nah herankommen soll. Der Text der Notiz steht in GameState.NOTES.

@export var note_id: String = ""


func _ready() -> void:
	if not GameState.NOTES.has(note_id):
		push_warning("NoteTrigger %s: keine Notiz mit der ID \"%s\" in GameState.NOTES" % [get_path(), note_id])
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		GameState.unlock_note(note_id)
