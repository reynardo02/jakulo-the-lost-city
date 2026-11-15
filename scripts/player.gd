extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 5.0
const ROTATION_SPEED = 10.0

# Liane
const VINE_HAND_OFFSET = 2.0      # Abstand Füße -> Hände (Arme über dem Kopf)
const VINE_JUMP_BOOST = 3.0       # Extra-Höhe beim Loslassen
const VINE_REGRAB_COOLDOWN = 0.5  # verhindert sofortiges Wieder-Greifen
const VINE_CLIMB_SPEED = 2.0      # m/s beim Klettern an der Liane

# Schleichen
const SNEAK_SPEED_FACTOR = 0.45   # Anteil der normalen Geschwindigkeit
const SNEAK_IDLE_ANIM = "Crouch_Idle"   # aus tools/crouch_anim/build_anim.py
const SNEAK_WALK_ANIM = "Crouch_Walk"
const SNEAK_ANIMS := {
	SNEAK_IDLE_ANIM: "res://assets/character/anims/crouch_idle.res",
	SNEAK_WALK_ANIM: "res://assets/character/anims/crouch_walk.res",
}
const SNEAK_BLEND_TIME = 0.2      # Überblenden zwischen aufrecht und geduckt
const AIR_CONTROL = 0.3

# Sprung nach vorne
const FORWARD_JUMP_SPEED = 5.0    # Vorwärtsschwung (zusätzlich zur Luftsteuerung)
const FORWARD_JUMP_VELOCITY = 5.0  # Sprunghöhe beim Sprung nach vorne           # Lenkbarkeit in der Luft nach der Liane
const VINE_ANIM = "Rope_Hang_Idle"

# Krokodilmaul aufstemmen (Werte passen zur Animation aus tools/croc_hang_anim/build_anim.py)
const CROC_BRACE_ANIM = "Croc_Jaw_Brace"
const CROC_PUSH_ANIM = "Croc_Jaw_Push"
const CROC_GRIP_HEIGHT = 1.64   # Mitte zwischen den Händen über den Füßen
const CROC_GRIP_FORWARD = 0.07  # ... vor dem Körper
const CROC_SHOULDER_HEIGHT = 1.3
const CROC_SHOULDER_HALF_WIDTH = 0.16
const CROC_ARM_REACH = 0.5      # Schulter -> Griffpunkt, fast gestreckt
const CROC_WRIST_OFFSET = 0.08  # Handgelenk sitzt etwas vor dem Griffpunkt
const CROC_TURN_WEIGHT = 0.2    # wie schnell sich die Figur quer zum Maul dreht
const CROC_IK_BLEND_TIME = 0.15


@onready var visuals: Node3D = $visuals

var current_vine: Node3D = null
var last_vine: Node3D = null     # zuletzt losgelassene Liane – erst nach Landung wieder greifbar
var vine_cooldown: float = 0.0
var is_sneaking: bool = false   # geduckt: langsamer, leiser, schwerer zu sehen
var hiding_zones: int = 0       # in so vielen Verstecken (hohes Gras) steht der Spieler gerade
var vine_climb_up_armed: bool = false  # Hochklettern erst, nachdem VOR einmal losgelassen wurde
var air_momentum: Vector3 = Vector3.ZERO
var hang_forward: Vector3 = Vector3.FORWARD  # Blickrichtung an der Liane (bleibt fest)

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm_3d: SpringArm3D = $CameraPivot/SpringArm3D
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = \
	animation_tree.get("parameters/playback")

# Arm-IK beim Aufstemmen: Index 0 = linker Arm, 1 = rechter Arm
var arm_ik: TwoBoneIK3D
var hand_targets: Array[Marker3D] = []
var elbow_poles: Array[Marker3D] = []
var arm_ik_tween: Tween

const MOUSE_SENSITY = 0.003
const STICK_YAW_SPEED = 2.8     # rad/s: Kamera drehen mit dem rechten Stick
const STICK_PITCH_SPEED = 1.8   # rad/s: Kamera neigen mit dem rechten Stick
func _ready() -> void:
	# Nach einem Tod am letzten Checkpoint statt am Levelanfang starten
	if GameState.has_checkpoint():
		global_position = GameState.get_respawn_position()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm_3d.add_excluded_object(get_rid())

	setup_sneak_animations()
	animation_tree.active = true
	playback.start("Idle_9")
	setup_arm_ik()
	
func _unhandled_input(event: InputEvent) -> void:	
	if event is InputEventMouseMotion:
		camera_pivot.rotate_y(-event.relative.x * MOUSE_SENSITY)
		spring_arm_3d.rotate_x(-event.relative.y * MOUSE_SENSITY)
		
		spring_arm_3d.rotation.x = clamp(
			spring_arm_3d.rotation.x,
			deg_to_rad(-60),
			deg_to_rad(30)
		)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	# Kamera mit dem rechten Stick des Controllers (läuft auch an der Liane und im Krokodilmaul)
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if look == Vector2.ZERO:
		return
	camera_pivot.rotate_y(-look.x * STICK_YAW_SPEED * delta)
	spring_arm_3d.rotation.x = clamp(
		spring_arm_3d.rotation.x - look.y * STICK_PITCH_SPEED * delta,
		deg_to_rad(-60),
		deg_to_rad(30)
	)
	

func _physics_process(delta: float) -> void:
	if vine_cooldown > 0.0:
		vine_cooldown -= delta

	update_sneak(delta)

	# An der Liane: Position folgt dem Seilende
	if current_vine:
		process_vine()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# movement via key press
	var input_dir= Input.get_vector("move_left",
		"move_right",
		"move_forward",
		"move_backward")
		
	#Convert direction to 3D
	var camera_basis = camera_pivot.global_transform.basis
	
	# Minus, weil SpringArm3D um 180° gedreht ist (Kamera schaut entlang +Z des Pivots)
	# Länge = Ausschlag des Sticks (Tastatur immer 1): leicht gekippt geht die Figur langsam
	var direction = -Vector3(camera_basis.x * input_dir.x +
		camera_basis.z * input_dir.y).normalized() * minf(input_dir.length(), 1.0)
		
	rotate_character(direction, delta)

	# jump – beim Laufen als Sprung nach vorne mit Schwung, im Stand senkrecht
	if Input.is_action_just_pressed("jump") and is_on_floor():
		is_sneaking = false   # Springen richtet auf
		velocity.y = JUMP_VELOCITY
		if direction.length_squared() > 0.01:
			velocity.y = FORWARD_JUMP_VELOCITY
			air_momentum = direction * FORWARD_JUMP_SPEED

	
	#Set horizontal direction (mit Schwung nach dem Loslassen der Liane)
	if air_momentum != Vector3.ZERO:
		velocity.x = air_momentum.x + direction.x * SPEED * AIR_CONTROL
		velocity.z = air_momentum.z + direction.z * SPEED * AIR_CONTROL
	else:
		var speed := SPEED * (SNEAK_SPEED_FACTOR if is_sneaking else 1.0)
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	
	#Moving the player and avoiding collisions
	move_and_slide()

	if is_on_floor():
		air_momentum = Vector3.ZERO
		last_vine = null

	update_animation()

# ---------- Schleichen ----------

## Hängt die Duck-Animationen in die Bibliothek "extra" und als Zustände in den AnimationTree.
## Passiert beim Start, damit scenes/player.tscn dafür nicht angefasst werden muss.
func setup_sneak_animations() -> void:
	var anim_player := animation_tree.get_node(animation_tree.anim_player) as AnimationPlayer
	var library := anim_player.get_animation_library(&"extra")
	var machine := animation_tree.tree_root as AnimationNodeStateMachine
	for state in SNEAK_ANIMS:
		if not library.has_animation(state):
			library.add_animation(state, load(SNEAK_ANIMS[state]))
		if not machine.has_node(state):
			var node := AnimationNodeAnimation.new()
			node.animation = "extra/" + state
			machine.add_node(state, node)
	# weiche Übergänge zwischen allen Steh-/Geh-Zuständen, aufrecht wie geduckt
	var states := ["Idle_9", "Walking", SNEAK_IDLE_ANIM, SNEAK_WALK_ANIM]
	for from in states:
		for to in states:
			var involves_sneak: bool = from in SNEAK_ANIMS or to in SNEAK_ANIMS
			if from == to or not involves_sneak or machine.has_transition(from, to):
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = SNEAK_BLEND_TIME
			machine.add_transition(from, to, transition)



## Ducken an/aus mit "crouch". An der Liane und in der Luft steht die Figur immer aufrecht.
func update_sneak(_delta: float) -> void:
	if current_vine or not is_on_floor():
		is_sneaking = false
	elif Input.is_action_just_pressed("crouch"):
		is_sneaking = not is_sneaking
	GameState.set_player_status("Versteckt" if is_hidden() else ("Schleichen" if is_sneaking else ""))


## Geduckt in einem Versteck (hohes Gras): Wachen sehen den Spieler dann nicht.
func is_hidden() -> bool:
	return is_sneaking and hiding_zones > 0


# ---------- Liane ----------

func grab_vine(vine: Node3D) -> void:
	# Nur im Sprung greifen, nicht direkt nach dem Loslassen
	if current_vine or vine_cooldown > 0.0 or is_on_floor() or vine == last_vine:
		return
	current_vine = vine
	vine_climb_up_armed = false
	vine.attach(velocity, global_position + Vector3.UP * VINE_HAND_OFFSET)
	hang_forward = vine.get_swing_direction()
	velocity = Vector3.ZERO
	air_momentum = Vector3.ZERO

func process_vine() -> void:
	# Klettern: ZURÜCK = nach unten (mehr Schwung), VOR = nach oben
	# Wer mit gedrücktem VOR an die Liane springt, soll nicht sofort hochklettern:
	# nach oben geht es erst, nachdem VOR einmal losgelassen wurde.
	if not Input.is_action_pressed("move_forward"):
		vine_climb_up_armed = true
	var climb := Input.get_axis("move_forward", "move_backward")
	if climb < 0.0 and not vine_climb_up_armed:
		climb = 0.0
	if climb != 0.0:
		current_vine.climb(climb * VINE_CLIMB_SPEED * get_physics_process_delta_time())

	# Hände am Haltepunkt, Körper hängt entlang des Seils
	var rope_up: Vector3 = current_vine.get_rope_up()
	global_position = current_vine.get_hold_position() - rope_up * VINE_HAND_OFFSET
	set_visual_orientation(rope_up, hang_forward)

	update_animation()

	if Input.is_action_just_pressed("jump"):
		release_vine()

func release_vine() -> void:
	var v: Vector3 = current_vine.get_hold_velocity()
	air_momentum = Vector3(v.x, 0.0, v.z)

	# Figur wieder aufrichten, Blick in Flugrichtung
	var fly_dir := air_momentum if air_momentum.length() > 0.5 else hang_forward
	set_visual_orientation(Vector3.UP, fly_dir)

	velocity = Vector3(v.x, maxf(v.y, 0.0) + VINE_JUMP_BOOST, v.z)
	current_vine.detach()
	last_vine = current_vine
	current_vine = null
	vine_cooldown = VINE_REGRAB_COOLDOWN

## Richtet die Figur aus: "up" = Körperachse, "forward" = Blickrichtung
func set_visual_orientation(up: Vector3, forward: Vector3) -> void:
	var z := (forward - up * forward.dot(up)).normalized()
	if z.length_squared() < 0.001:
		return
	var x := up.cross(z).normalized()
	visuals.global_basis = Basis(x, up.normalized(), z)

# ---------- Gefangen (z. B. im Maul des Krokodils) ----------

## Hält den Spieler fest: keine Steuerung, keine Physik. Er stemmt das Maul mit beiden
## Händen auf, die Position setzt der Fänger über brace_between().
func capture() -> void:
	if current_vine:
		current_vine.detach()
		current_vine = null
	velocity = Vector3.ZERO
	air_momentum = Vector3.ZERO
	set_physics_process(false)
	set_visual_orientation(Vector3.UP, get_visual_forward())
	playback.travel(CROC_BRACE_ANIM)
	blend_arm_ik(true)

## Blickrichtung der Figur, waagerecht
func get_visual_forward() -> Vector3:
	var fwd := visuals.global_basis.z
	fwd.y = 0.0
	return fwd.normalized() if fwd.length_squared() > 0.001 else Vector3.FORWARD

## Mitte zwischen den Händen beim Aufstemmen - von der aktuellen Position aus gesehen.
func get_grip_point() -> Vector3:
	return global_position + Vector3.UP * CROC_GRIP_HEIGHT + get_visual_forward() * CROC_GRIP_FORWARD

## Stemmt zwei Punkte (Ober- und Unterkiefer) auseinander: je eine Hand an jedem Punkt,
## der Körper hängt mittig darunter und schaut quer dazu ("facing" oder Gegenrichtung).
func brace_between(grip_a: Vector3, grip_b: Vector3, facing: Vector3) -> void:
	facing.y = 0.0
	if facing.length_squared() > 0.01:
		# die Richtung nehmen, die näher an der aktuellen Blickrichtung liegt
		if facing.dot(get_visual_forward()) < 0.0:
			facing = -facing
		var target := Basis.looking_at(-facing.normalized(), Vector3.UP)
		visuals.global_basis = visuals.global_basis.orthonormalized().slerp(target, CROC_TURN_WEIGHT)
	var forward := get_visual_forward()
	# Je weiter die Griffe auseinander sind, desto höher rutscht der Körper zwischen sie,
	# damit die Arme sie noch erreichen.
	var side := grip_a.distance_to(grip_b) * 0.5 - CROC_SHOULDER_HALF_WIDTH
	var above_shoulder := sqrt(maxf(CROC_ARM_REACH * CROC_ARM_REACH - side * side, 0.0))
	var grip_height := minf(CROC_GRIP_HEIGHT, CROC_SHOULDER_HEIGHT + above_shoulder)
	global_position = (grip_a + grip_b) * 0.5 - Vector3.UP * grip_height - forward * CROC_GRIP_FORWARD

	# Linke Hand (+X der Figur) an den Punkt, der links liegt
	var grips := [grip_a, grip_b] if (grip_a - grip_b).dot(visuals.global_basis.x) > 0.0 else [grip_b, grip_a]
	var shoulder := global_position + Vector3.UP * CROC_SHOULDER_HEIGHT
	for i in 2:
		var grip: Vector3 = grips[i]
		hand_targets[i].global_position = grip - (grip - shoulder).normalized() * CROC_WRIST_OFFSET
		# Ellbogen zeigen nach unten und leicht nach hinten
		elbow_poles[i].global_position = (grip + shoulder) * 0.5 + Vector3.DOWN * 0.6 - forward * 0.4

## Ein Befreiungsversuch: Stoß gegen die Kiefer.
func struggle() -> void:
	playback.start(CROC_PUSH_ANIM)

## Gibt den Spieler wieder frei und schleudert ihn mit "launch" weg.
func escape(launch: Vector3) -> void:
	velocity = launch
	air_momentum = Vector3(launch.x, 0.0, launch.z)
	set_physics_process(true)
	blend_arm_ik(false)
	playback.travel("Jump_with_Arms_Open")

## IK für beide Arme. Ist nur beim Aufstemmen aktiv und zieht die Hände an hand_targets.
func setup_arm_ik() -> void:
	var skeleton: Skeleton3D = visuals.find_children("*", "Skeleton3D", true, false)[0]
	arm_ik = TwoBoneIK3D.new()
	arm_ik.active = false
	arm_ik.influence = 0.0
	skeleton.add_child(arm_ik)
	arm_ik.setting_count = 2
	for i in 2:
		var side: String = ["Left", "Right"][i]
		var target := Marker3D.new()
		var pole := Marker3D.new()
		target.top_level = true
		pole.top_level = true
		add_child(target)
		add_child(pole)
		hand_targets.append(target)
		elbow_poles.append(pole)
		arm_ik.set_root_bone_name(i, "mixamorig_%sArm" % side)
		arm_ik.set_middle_bone_name(i, "mixamorig_%sForeArm" % side)
		arm_ik.set_end_bone_name(i, "mixamorig_%sHand" % side)
		arm_ik.set_target_node(i, arm_ik.get_path_to(target))
		arm_ik.set_pole_node(i, arm_ik.get_path_to(pole))

## Arm-IK weich ein- oder ausblenden.
func blend_arm_ik(on: bool) -> void:
	if arm_ik_tween:
		arm_ik_tween.kill()
	if on:
		arm_ik.active = true
	arm_ik_tween = create_tween()
	arm_ik_tween.tween_property(arm_ik, "influence", 1.0 if on else 0.0, CROC_IK_BLEND_TIME)
	if not on:
		arm_ik_tween.tween_callback(func(): arm_ik.active = false)

# ---------- Animation ----------
	
func update_animation() -> void:
	var target_state: String
	if current_vine and (animation_tree.tree_root as AnimationNodeStateMachine).has_node(VINE_ANIM):
		target_state = VINE_ANIM
	elif current_vine or not is_on_floor():
		target_state = "Jump_with_Arms_Open"
	elif Vector2(velocity.x, velocity.z).length() > 0.1:
		target_state = SNEAK_WALK_ANIM if is_sneaking else "Walking"
	else:
		target_state = SNEAK_IDLE_ANIM if is_sneaking else "Idle_9"

	# Nur wechseln, wenn sich der State ändert – sonst startet die Animation jeden Frame neu
	if playback.get_current_node() != target_state:
		playback.travel(target_state)
		
func rotate_character(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.001:
		return

	var target_angle = atan2(-direction.x, -direction.z)

	visuals.rotation.y = lerp_angle(
		visuals.rotation.y,
		target_angle,
		min(ROTATION_SPEED * delta, 1.0)
	)
