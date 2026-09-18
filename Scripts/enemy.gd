extends CharacterBody2D


# ============================================
# NODES
# ============================================

@onready var anim_tree: AnimationTree = $Sprite2D/AnimationTree
@onready var anim_player: AnimationPlayer = $Sprite2D/AnimationPlayer

@onready var state_machine: AnimationNodeStateMachinePlayback = (
	anim_tree["parameters/playback"]
)

@onready var hurt_timer: Timer = $HurtTimer
@onready var attack_timer: Timer = $AttackTimer

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_hitbox: Area2D = $AttackHitbox


# ============================================
# ENEMY SETTINGS
# ============================================

var speed: float
var hurt_duration: float

var attack_distance: float
var attack_damage: int
var attack_duration: float

var max_health: int
var current_health: int

var separation_radius: float
var separation_strength: float


# ============================================
# MOVEMENT
# ============================================

var movement_direction := Vector2.DOWN
var facing_direction := Vector2.DOWN

var is_locked := false
var is_dead := false

var player: CharacterBody2D


# ============================================
# ATTACK
# ============================================

var player_hurtbox: Area2D = null


# ============================================
# READY
# ============================================

func _ready() -> void:

	# ============================================
	# LOAD GLOBAL ENEMY SETTINGS
	# ============================================

	speed = GameSettings.ENEMY_SPEED
	hurt_duration = GameSettings.ENEMY_HURT_DURATION

	attack_distance = GameSettings.ENEMY_ATTACK_DISTANCE
	attack_damage = GameSettings.ENEMY_ATTACK_DAMAGE
	attack_duration = GameSettings.ENEMY_ATTACK_DURATION

	max_health = GameSettings.ENEMY_MAX_HEALTH
	current_health = max_health

	separation_radius = GameSettings.ENEMY_SEPARATION_RADIUS
	separation_strength = GameSettings.ENEMY_SEPARATION_STRENGTH


	# ============================================
	# ENEMY SIZE
	# ============================================

	scale = Vector2.ONE * GameSettings.ENEMY_SIZE


	# ============================================
	# ANIMATION
	# ============================================

	anim_tree.active = true


	# ============================================
	# HURT TIMER
	# ============================================

	hurt_timer.one_shot = true
	hurt_timer.wait_time = hurt_duration

	hurt_timer.timeout.connect(
		_on_hurt_timer_timeout
	)


	# ============================================
	# ATTACK TIMER
	# ============================================

	attack_timer.one_shot = true
	attack_timer.wait_time = attack_duration

	attack_timer.timeout.connect(
		_on_attack_timer_timeout
	)


	# ============================================
	# ATTACK HITBOX
	# ============================================

	attack_hitbox.area_entered.connect(
		_on_attack_hitbox_entered
	)

	attack_hitbox.area_exited.connect(
		_on_attack_hitbox_exited
	)


	# ============================================
	# FIND PLAYER
	# ============================================

	player = get_tree().get_first_node_in_group(
		"player"
	)


# ============================================
# PHYSICS
# ============================================

func _physics_process(_delta: float) -> void:

	if is_locked:
		return


	if player:

		var player_offset: Vector2 = (
			player.global_position
			- global_position
		)

		var enemy_separation: Vector2 = (
			get_separation_vector(
				separation_radius
			)
			* separation_strength
		)

		var player_separation: Vector2 = (
			get_player_separation(
				attack_distance
			)
			* separation_strength
		)


		# ========================================
		# MOVE TOWARD PLAYER
		# ========================================

		if (
			player_offset.length()
			>= attack_distance
		):

			velocity = (
				player_offset.normalized() * speed
				+ enemy_separation
			).normalized() * speed * (
				current_health * 1.0
				/ max_health
			)


		# ========================================
		# CLOSE TO PLAYER
		# ========================================

		else:

			velocity = (
				player_separation
				+ enemy_separation
			).normalized() * speed * (
				current_health * 1.0
				/ max_health
			)


		# ========================================
		# FACING DIRECTION
		# ========================================

		if velocity.length() > 0.0:
			facing_direction = velocity.normalized()


	# ============================================
	# ANIMATION
	# ============================================

	if velocity.length() != 0.0:

		movement_direction = velocity.normalized()

		travel_to("walk")

	else:

		travel_to("idle")


	move_and_slide()


# ============================================
# ENEMY SEPARATION
# ============================================

func get_separation_vector(
	radius: float
) -> Vector2:

	var push := Vector2.ZERO

	var enemies = (
		get_tree().get_nodes_in_group(
			"enemies"
		)
	)


	for other in enemies:

		if other == self:
			continue


		var dist: float = (
			global_position.distance_to(
				other.global_position
			)
		)


		if dist < radius and dist > 0.0:

			var away: Vector2 = (
				global_position
				- other.global_position
			).normalized()

			push += (
				away
				* (radius - dist)
				/ radius
			)


	return push


# ============================================
# PLAYER SEPARATION
# ============================================

func get_player_separation(
	radius: float
) -> Vector2:

	if not player:
		return Vector2.ZERO


	var dist: float = (
		global_position.distance_to(
			player.global_position
		)
	)


	if dist < radius and dist > 0.0:

		var away: Vector2 = (
			global_position
			- player.global_position
		).normalized()

		return (
			away
			* (radius - dist)
			/ radius
		)


	return Vector2.ZERO


# ============================================
# TAKE DAMAGE
# ============================================

func take_damage(amount: int) -> void:

	if is_dead:
		return


	current_health -= amount


	if current_health <= 0:

		die()

		return


	is_locked = true

	travel_to("hurt")

	hurt_timer.start()


# ============================================
# HURT TIMER
# ============================================

func _on_hurt_timer_timeout() -> void:

	if not is_dead:
		is_locked = false


# ============================================
# ATTACK HITBOX ENTERED
# ============================================

func _on_attack_hitbox_entered(
	area: Area2D
) -> void:

	if area.name != "Hurtbox":
		return


	player_hurtbox = area


	# Attack immediately when touching
	# the player's Hurtbox.
	attack_player()


# ============================================
# ATTACK HITBOX EXITED
# ============================================

func _on_attack_hitbox_exited(
	area: Area2D
) -> void:

	if area == player_hurtbox:
		player_hurtbox = null


# ============================================
# ATTACK PLAYER
# ============================================

func attack_player() -> void:

	if is_dead:
		return


	if player_hurtbox == null:
		return


	if not attack_timer.is_stopped():
		return


	var character = (
		player_hurtbox.get_parent()
	)


	if character.has_method(
		"take_damage"
	):

		character.take_damage(
			attack_damage
		)

		attack_timer.start()


# ============================================
# ATTACK TIMER FINISHED
# ============================================

func _on_attack_timer_timeout() -> void:

	# If the player is still inside the
	# attack hitbox, attack again.
	if player_hurtbox != null:
		attack_player()


# ============================================
# DIE
# ============================================

func die() -> void:

	is_locked = true
	is_dead = true

	velocity = Vector2.ZERO

	# Disable physical movement collision.
	collision_shape.set_deferred(
		"disabled",
		true
	)

	# Stop the enemy from detecting anything.
	attack_hitbox.set_deferred(
		"monitoring",
		false
	)

	# Stop bullets from detecting the enemy's hitbox.
	attack_hitbox.set_deferred(
		"monitorable",
		false
	)

	player_hurtbox = null

	travel_to("death")

	await get_tree().create_timer(
		5.0
	).timeout

	queue_free()


# ============================================
# ANIMATION STATE
# ============================================

func travel_to(
	state_name: String
) -> void:

	if (
		state_machine.get_current_node()
		!= state_name
	):

		state_machine.travel(
			state_name
		)


	anim_tree.set(
		"parameters/"
		+ state_name
		+ "/blend_position",
		facing_direction
	)
