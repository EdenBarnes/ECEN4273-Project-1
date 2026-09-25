extends CharacterBody2D


# ============================================
# NODES
# ============================================

@onready var anim_tree: AnimationTree = $Sprite2D/AnimationTree
@onready var anim_player: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var state_machine: AnimationNodeStateMachinePlayback = anim_tree["parameters/playback"]

@onready var hurt_timer: Timer = $HurtTimer
@onready var attack_timer: Timer = $AttackTimer

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_hitbox: Area2D = $AttackHitbox

@onready var avoid_left: RayCast2D = $AvoidLeft
@onready var avoid_center: RayCast2D = $AvoidCenter
@onready var avoid_right: RayCast2D = $AvoidRight


# ============================================
# BIG GUY SETTINGS
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

var obstacle_avoid_distance: float
var obstacle_avoid_strength: float


# ============================================
# MOVEMENT
# ============================================

var movement_direction: Vector2 = Vector2.DOWN
var facing_direction: Vector2 = Vector2.DOWN

var is_locked: bool = false
var is_dead: bool = false

var player: CharacterBody2D = null


# ============================================
# ATTACK
# ============================================

var player_hurtbox: Area2D = null


# ============================================
# READY
# ============================================

func _ready() -> void:
	# Big Guy settings
	speed = GameSettings.ENEMY_SPEED - 50.0
	hurt_duration = GameSettings.ENEMY_HURT_DURATION

	attack_distance = GameSettings.ENEMY_ATTACK_DISTANCE + 10.0
	attack_damage = GameSettings.ENEMY_ATTACK_DAMAGE + 5
	attack_duration = GameSettings.ENEMY_ATTACK_DURATION

	max_health = GameSettings.ENEMY_MAX_HEALTH + 100
	current_health = max_health

	separation_radius = GameSettings.ENEMY_SEPARATION_RADIUS
	separation_strength = GameSettings.ENEMY_SEPARATION_STRENGTH

	obstacle_avoid_distance = GameSettings.ENEMY_OBSTACLE_AVOID_DISTANCE
	obstacle_avoid_strength = GameSettings.ENEMY_OBSTACLE_AVOID_STRENGTH

	# Big Guy is larger
	scale = Vector2.ONE * (GameSettings.ENEMY_SIZE + 2.0)

	# Animation
	anim_tree.active = true

	# Hurt timer
	hurt_timer.one_shot = true
	hurt_timer.wait_time = hurt_duration
	hurt_timer.timeout.connect(_on_hurt_timer_timeout)

	# Attack timer
	attack_timer.one_shot = true
	attack_timer.wait_time = attack_duration
	attack_timer.timeout.connect(_on_attack_timer_timeout)

	# Attack hitbox
	attack_hitbox.area_entered.connect(_on_attack_hitbox_entered)
	attack_hitbox.area_exited.connect(_on_attack_hitbox_exited)

	# Obstacle avoidance
	avoid_left.enabled = true
	avoid_center.enabled = true
	avoid_right.enabled = true

	avoid_left.collision_mask = 8
	avoid_center.collision_mask = 8
	avoid_right.collision_mask = 8

	avoid_left.collide_with_areas = false
	avoid_center.collide_with_areas = false
	avoid_right.collide_with_areas = false

	avoid_left.collide_with_bodies = true
	avoid_center.collide_with_bodies = true
	avoid_right.collide_with_bodies = true

	# Find player
	player = get_tree().get_first_node_in_group("player")


# ============================================
# PHYSICS
# ============================================

func _physics_process(_delta: float) -> void:
	if is_locked:
		return

	if player:
		var player_offset: Vector2 = player.global_position - global_position
		var enemy_separation: Vector2 = get_separation_vector(separation_radius) * separation_strength
		var player_separation: Vector2 = get_player_separation(attack_distance) * separation_strength
		var desired_direction: Vector2 = Vector2.ZERO

		# Move toward player
		if player_offset.length() >= attack_distance:
			desired_direction = player_offset.normalized() + enemy_separation

		# Close to player
		else:
			desired_direction = player_separation + enemy_separation

		# Obstacle avoidance
		if desired_direction != Vector2.ZERO:
			desired_direction = desired_direction.normalized()

			var obstacle_avoidance: Vector2 = get_obstacle_avoidance(desired_direction)
			desired_direction = (desired_direction + obstacle_avoidance).normalized()

			var health_speed_multiplier: float = float(current_health) / float(max_health)
			velocity = desired_direction * speed * health_speed_multiplier
		else:
			velocity = Vector2.ZERO

		# Facing direction
		if velocity.length() > 0.0:
			facing_direction = velocity.normalized()

	# Animation
	if velocity.length() > 0.0:
		movement_direction = velocity.normalized()
		travel_to("walk")
	else:
		travel_to("idle")

	move_and_slide()


# ============================================
# OBSTACLE AVOIDANCE
# ============================================

func get_obstacle_avoidance(move_direction: Vector2) -> Vector2:
	if move_direction == Vector2.ZERO:
		return Vector2.ZERO

	var left_direction: Vector2 = move_direction.rotated(deg_to_rad(-30.0))
	var right_direction: Vector2 = move_direction.rotated(deg_to_rad(30.0))

	avoid_center.target_position = move_direction * obstacle_avoid_distance
	avoid_left.target_position = left_direction * obstacle_avoid_distance
	avoid_right.target_position = right_direction * obstacle_avoid_distance

	avoid_center.force_raycast_update()
	avoid_left.force_raycast_update()
	avoid_right.force_raycast_update()

	var center_blocked: bool = avoid_center.is_colliding()
	var left_blocked: bool = avoid_left.is_colliding()
	var right_blocked: bool = avoid_right.is_colliding()

	var avoidance: Vector2 = Vector2.ZERO

	# Nothing blocked
	if not center_blocked and not left_blocked and not right_blocked:
		return Vector2.ZERO

	# Left blocked, steer right
	if left_blocked and not right_blocked:
		avoidance = move_direction.rotated(deg_to_rad(90.0))

	# Right blocked, steer left
	elif right_blocked and not left_blocked:
		avoidance = move_direction.rotated(deg_to_rad(-90.0))

	# Center blocked
	elif center_blocked:
		if not left_blocked:
			avoidance = move_direction.rotated(deg_to_rad(-90.0))
		elif not right_blocked:
			avoidance = move_direction.rotated(deg_to_rad(90.0))
		else:
			avoidance = move_direction.rotated(deg_to_rad(90.0))

	return avoidance * obstacle_avoid_strength


# ============================================
# ENEMY SEPARATION
# ============================================

func get_separation_vector(radius: float) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")

	for other: Node in enemies:
		if other == self:
			continue

		if not other is Node2D:
			continue

		var other_enemy: Node2D = other as Node2D
		var dist: float = global_position.distance_to(other_enemy.global_position)

		if dist < radius and dist > 0.0:
			var away: Vector2 = (global_position - other_enemy.global_position).normalized()
			push += away * (radius - dist) / radius

	return push


# ============================================
# PLAYER SEPARATION
# ============================================

func get_player_separation(radius: float) -> Vector2:
	if not player:
		return Vector2.ZERO

	var dist: float = global_position.distance_to(player.global_position)

	if dist < radius and dist > 0.0:
		var away: Vector2 = (global_position - player.global_position).normalized()
		return away * (radius - dist) / radius

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
	velocity = Vector2.ZERO

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

func _on_attack_hitbox_entered(area: Area2D) -> void:
	if area.name != "Hurtbox":
		return

	player_hurtbox = area
	attack_player()


# ============================================
# ATTACK HITBOX EXITED
# ============================================

func _on_attack_hitbox_exited(area: Area2D) -> void:
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

	var character: Node = player_hurtbox.get_parent()

	if character.has_method("take_damage"):
		character.take_damage(attack_damage)
		attack_timer.start()


# ============================================
# ATTACK TIMER FINISHED
# ============================================

func _on_attack_timer_timeout() -> void:
	if player_hurtbox != null:
		attack_player()


# ============================================
# DIE
# ============================================

func die() -> void:
	if is_dead:
		return

	is_locked = true
	is_dead = true
	velocity = Vector2.ZERO

	# Disable collisions
	collision_shape.set_deferred("disabled", true)
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox.set_deferred("monitorable", false)

	# ============================================
	# NOTIFY WAVE MANAGER IMMEDIATELY
	# ============================================

	var wave_manager: Node = get_tree().get_first_node_in_group("wave_manager")

	if wave_manager != null and wave_manager.has_method("on_enemy_died"):
		wave_manager.on_enemy_died()

	# ============================================
	# DEATH ANIMATION
	# ============================================

	travel_to("death")

	await get_tree().create_timer(5.0).timeout

	queue_free()


# ============================================
# ANIMATION
# ============================================

func travel_to(state_name: String) -> void:
	if state_machine.get_current_node() != state_name:
		state_machine.travel(state_name)

	anim_tree.set("parameters/" + state_name + "/blend_position", facing_direction)
