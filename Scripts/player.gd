extends CharacterBody2D

@onready var anim_tree: AnimationTree = $Sprite2D/AnimationTree
@onready var anim_player: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var state_machine: AnimationNodeStateMachinePlayback = anim_tree["parameters/playback"]
@onready var hurt_timer: Timer = $HurtTimer
@onready var invulnerability_timer: Timer = $InvulnerabilityTimer

@onready var weapon_holder: Node2D = $WeaponHolder
@onready var current_gun = $WeaponHolder/Gun
@onready var aim_cone: Node2D = $WeaponHolder/Gun/AimCone


var speed: float = 50.0
var hurt_duration: float = 0.5
var invulnerability_duration: float = 2.0
var max_health: int = 100
var current_health: int = 100


var movement_direction := Vector2.DOWN
var facing_direction := Vector2.DOWN

var is_locked := false
var is_dead := false


func _ready() -> void:
	# ============================================
	# LOAD PLAYER SETTINGS
	# ============================================

	speed = GameSettings.PLAYER_SPEED
	hurt_duration = GameSettings.PLAYER_HURT_DURATION
	invulnerability_duration = GameSettings.PLAYER_INVULNERABILITY_DURATION
	max_health = GameSettings.PLAYER_MAX_HEALTH
	current_health = max_health

	scale = Vector2.ONE * GameSettings.PLAYER_SIZE


	# ============================================
	# ANIMATION SETUP
	# ============================================

	anim_tree.active = true


	# ============================================
	# HURT TIMER SETUP
	# ============================================

	hurt_timer.one_shot = true
	hurt_timer.wait_time = hurt_duration
	hurt_timer.timeout.connect(_on_hurt_timer_timeout)

	invulnerability_timer.one_shot = true

	# ============================================
	# PLAYER START POSITION
	# ============================================

	position = get_viewport_rect().size / 2.0


func _physics_process(_delta: float) -> void:
	if is_locked:
		return

	var is_aiming := Input.is_action_pressed("aim")

	current_gun.set_aiming(is_aiming)

	# ============================================
	# MOVEMENT INPUT
	# ============================================

	var input_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)


	# ============================================
	# AIMING
	# ============================================

	var mouse_pos: Vector2 = get_global_mouse_position()

	facing_direction = (
		mouse_pos - global_position
	).normalized()


	# Rotate the weapon holder toward the mouse
	weapon_holder.rotation = facing_direction.angle()


	# Flip the gun sprite when aiming left
	current_gun.update_visual(facing_direction)


	# ============================================
	# AIM CONE
	# ============================================

	if current_gun.weapon_data:
		aim_cone.spread_angle = current_gun.get_current_spread()
		aim_cone.cone_length = current_gun.weapon_data.aim_cone_length
		aim_cone.cone_start_distance = current_gun.weapon_data.aim_cone_start_distance


	# ============================================
	# MOVEMENT
	# ============================================

	var current_speed := speed

	if is_aiming and current_gun.weapon_data:
		current_speed *= current_gun.weapon_data.aim_move_speed_multiplier


	if input_vector != Vector2.ZERO:
		movement_direction = input_vector.normalized()

		velocity = movement_direction * current_speed

		travel_to("walk")

	else:
		velocity = Vector2.ZERO

		travel_to("idle")


	# ============================================
	# SHOOTING
	# ============================================

	if Input.is_action_pressed("shoot"):
		current_gun.shoot(facing_direction)

	if Input.is_action_just_pressed("reload"):
		current_gun.reload()

	move_and_slide()


func take_damage(amount: int) -> void:
	if is_dead:
		return

	if not invulnerability_timer.is_stopped():
		return

	current_health -= amount

	invulnerability_timer.start(invulnerability_duration)

	if current_health <= 0:
		die()
		return

	is_locked = true
	travel_to("hurt")
	hurt_timer.start()


func _on_hurt_timer_timeout() -> void:
	if !is_dead:
		is_locked = false


func die() -> void:
	is_locked = true
	is_dead = true

	travel_to("death")

	await get_tree().create_timer(5.0).timeout

	queue_free()


func travel_to(state_name: String) -> void:
	if state_machine.get_current_node() != state_name:
		state_machine.travel(state_name)

	anim_tree.set(
		"parameters/" + state_name + "/blend_position",
		facing_direction
	)
