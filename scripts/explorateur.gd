class_name Explorateur
extends CharacterBody3D
## Visite de l'île (jalon 0) : marcher, sprinter, sauter, nager, et un mode drone pour survoler
## la carte. Le vrai contrôleur de combat (glissade, annulation de glissade, parachute, armes)
## arrive au jalon 1 ; les valeurs de marche reprennent celles de Dernière Vague.

const WALK := 4.6
const SPRINT := 6.9
const GRAVITY := 18.0
const JUMP := 6.0
const FLY := 22.0
const FLY_FAST := 65.0
const LOOK_PAD := 150.0      # degrés par seconde au stick
const LOOK_MOUSE := 0.12
const WATER_LEVEL := -1.25   # les pieds à cette hauteur : on nage

var head: Node3D
var cam: Camera3D
var touch: TouchControls
var flying := false
var swimming := false
var auto_input := Vector2.ZERO   # tests automatiques : déplacement imposé
var _yaw := 0.0
var _pitch := 0.0
var _sprinting := false
var _step := 0.0


func _ready() -> void:
	collision_layer = G.L_PLAYER
	collision_mask = G.L_WORLD
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.5
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 75.0
	cam.near = 0.08
	cam.far = 2200.0
	head.add_child(cam)
	cam.current = true


func spawn_at(p: Vector3, yaw: float) -> void:
	global_position = p
	velocity = Vector3.ZERO
	_yaw = yaw
	_pitch = 0.0
	rotation.y = _yaw
	head.rotation.x = 0.0


func set_flying(on: bool) -> void:
	flying = on
	collision_mask = 0 if on else G.L_WORLD
	velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not OS.has_feature("mobile") and G.input_mode == "kbm":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(-event.relative.x * LOOK_MOUSE, -event.relative.y * LOOK_MOUSE)
	if event.is_action_pressed("drone"):
		set_flying(not flying)
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _look(dx_deg: float, dy_deg: float) -> void:
	_yaw += deg_to_rad(dx_deg)
	_pitch = clampf(_pitch + deg_to_rad(dy_deg), deg_to_rad(-88), deg_to_rad(88))
	rotation.y = _yaw
	head.rotation.x = _pitch


func _process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_down", "look_up")
	if stick != Vector2.ZERO:
		# Courbe douce : précis au centre, rapide en bout de course.
		var curved := stick * stick.length()
		_look(-curved.x * LOOK_PAD * delta, curved.y * LOOK_PAD * 0.75 * delta)
	if touch and touch.visible:
		var d := touch.consume_look()
		if d != Vector2.ZERO:
			_look(-d.x * 0.18, -d.y * 0.18)


func _move_input() -> Vector2:
	if auto_input != Vector2.ZERO:
		return auto_input
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch and touch.visible and touch.move.length() > input.length():
		input = touch.move
	return input


func _physics_process(delta: float) -> void:
	var input := _move_input()
	var want_sprint := Input.is_action_pressed("sprint") or (touch and touch.visible and touch.sprint)
	if G.input_mode == "pad":
		if Input.is_action_just_pressed("sprint"):
			_sprinting = not _sprinting
		if input.y > -0.3:
			_sprinting = false
	else:
		_sprinting = want_sprint
	var up := Input.is_action_pressed("jump") or (touch and touch.visible and touch.jump_held)
	var down := Input.is_action_pressed("descend") or (touch and touch.visible and touch.down_held)
	if flying:
		var speed := FLY_FAST if _sprinting or want_sprint else FLY
		var dir := cam.global_basis * Vector3(input.x, 0, input.y)
		dir.y += (1.0 if up else 0.0) - (1.0 if down else 0.0)
		velocity = velocity.lerp(dir.limit_length(1.0) * speed, minf(1.0, delta * 6.0))
		global_position += velocity * delta
		global_position.y = clampf(global_position.y, -8.0, 220.0)
		_keep_inside()
		return
	swimming = global_position.y < WATER_LEVEL
	var speed := (SPRINT if _sprinting else WALK) * (0.55 if swimming else 1.0)
	var dir := global_basis * Vector3(input.x, 0, input.y)
	dir.y = 0
	var target := dir * speed
	var accel := 12.0 if is_on_floor() or swimming else 3.0
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)
	if swimming:
		# On flotte : la tête reste hors de l'eau, on peut remonter sur la plage.
		velocity.y = move_toward(velocity.y, (WATER_LEVEL + 0.15 - global_position.y) * 4.0, 30.0 * delta)
		if up:
			velocity.y = 2.5
	elif is_on_floor():
		var jump := Input.is_action_just_pressed("jump") or (touch and touch.visible and touch.jump_pressed)
		if jump:
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	if touch:
		touch.jump_pressed = false
	move_and_slide()
	_keep_inside()
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hs > 1.0:
		_step += hs * delta
		if _step > (2.4 if _sprinting else 1.9):
			_step = 0.0
			G.play("step", -14.0, randf_range(0.85, 1.15))


## La mer a une limite : au-delà, un courant ramène vers l'île.
func _keep_inside() -> void:
	var limit := float(G.data.get("monde", 640)) / 2.0 - 8.0
	var p := global_position
	if absf(p.x) > limit or absf(p.z) > limit:
		global_position.x = clampf(p.x, -limit, limit)
		global_position.z = clampf(p.z, -limit, limit)
