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

var obstacle_avoid_distance: float
var obstacle_avoid_strength: float

# Extra clearance and time spent following an obstacle
@export var avoidance_padding: float = 2.0
@export var wall_follow_time: float = 0.45
@export var stuck_check_time: float = 0.5
@export var stuck_min_movement: float = 3.0
@export var escape_time: float = 0.9


# ============================================
# MOVEMENT
# ============================================

var movement_direction: Vector2 = Vector2.DOWN
var facing_direction: Vector2 = Vector2.DOWN

var is_locked: bool = false
var is_dead: bool = false

var player: CharacterBody2D = null

var avoidance_side: int = 0
var avoidance_time_left: float = 0.0
var escape_time_left: float = 0.0
var stuck_elapsed: float = 0.0
var stuck_position: Vector2 = Vector2.ZERO
var obstacle_normal: Vector2 = Vector2.ZERO
var collision_clearance: float = 8.0


# ============================================
# ATTACK
# ============================================

var player_hurtbox: Area2D = null


# ============================================
# READY
# ============================================

func _ready() -> void:
	# Enemy settings
	speed = GameSettings.ENEMY_SPEED
	hurt_duration = GameSettings.ENEMY_HURT_DURATION

	attack_distance = GameSettings.ENEMY_ATTACK_DISTANCE
	attack_damage = GameSettings.ENEMY_ATTACK_DAMAGE
	attack_duration = GameSettings.ENEMY_ATTACK_DURATION

	max_health = GameSettings.ENEMY_MAX_HEALTH
	current_health = max_health

	separation_radius = GameSettings.ENEMY_SEPARATION_RADIUS
	separation_strength = GameSettings.ENEMY_SEPARATION_STRENGTH

	obstacle_avoid_distance = GameSettings.ENEMY_OBSTACLE_AVOID_DISTANCE
	obstacle_avoid_strength = GameSettings.ENEMY_OBSTACLE_AVOID_STRENGTH

	# Enemy size
	scale = Vector2.ONE * GameSettings.ENEMY_SIZE

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
	avoid_left.exclude_parent = true
	avoid_center.exclude_parent = true
	avoid_right.exclude_parent = true
	collision_clearance = get_collision_clearance()
	stuck_position = global_position

	# Find player
	player = get_tree().get_first_node_in_group("player")


# ============================================
# PHYSICS
# ============================================

func _physics_process(delta: float) -> void:
	if is_locked or is_dead:
		return

	avoidance_time_left = maxf(avoidance_time_left - delta, 0.0)
	escape_time_left = maxf(escape_time_left - delta, 0.0)

	if player != null and is_instance_valid(player):
		var player_offset: Vector2 = player.global_position - global_position
		var enemy_separation: Vector2 = get_separation_vector(separation_radius) * separation_strength
		var player_separation: Vector2 = get_player_separation(attack_distance) * separation_strength
		var desired_direction: Vector2 = Vector2.ZERO

		if player_offset.length() >= attack_distance:
			desired_direction = player_offset.normalized() + enemy_separation
		else:
			desired_direction = player_separation + enemy_separation

		if desired_direction.length_squared() > 0.0001:
			desired_direction = desired_direction.normalized()
			desired_direction = get_obstacle_avoidance(desired_direction)

			var health_speed_multiplier: float = maxf(float(current_health) / maxf(float(max_health), 1.0), 0.25)
			velocity = desired_direction * speed * health_speed_multiplier
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	if velocity.length_squared() > 0.001:
		facing_direction = velocity.normalized()
		movement_direction = facing_direction
		travel_to("walk")
	else:
		travel_to("idle")

	var intended_movement: bool = velocity.length_squared() > 1.0
	move_and_slide()
	update_stuck_detection(delta, intended_movement)


# ============================================
# COLLISION CLEARANCE
# ============================================

func get_collision_clearance() -> float:
	if collision_shape == null or collision_shape.shape == null:
		return 8.0

	var shape: Shape2D = collision_shape.shape
	var radius: float = 8.0
	if shape is CircleShape2D:
		radius = (shape as CircleShape2D).radius
	elif shape is CapsuleShape2D:
		radius = (shape as CapsuleShape2D).radius
	elif shape is RectangleShape2D:
		radius = (shape as RectangleShape2D).size.x * 0.5

	return radius * maxf(absf(global_scale.x), absf(global_scale.y)) + avoidance_padding


# ============================================
# OBSTACLE AVOIDANCE
# ============================================

func get_obstacle_avoidance(move_direction: Vector2) -> Vector2:
	if move_direction == Vector2.ZERO:
		return Vector2.ZERO

	# Rays are cast from the center and both sides of the enemy.
	# Convert world directions to local space for scaled enemies.
	var side: Vector2 = Vector2(-move_direction.y, move_direction.x)
	var detection_distance: float = obstacle_avoid_distance + collision_clearance
	setup_avoid_ray(avoid_center, Vector2.ZERO, move_direction, detection_distance)
	setup_avoid_ray(avoid_left, -side * collision_clearance, move_direction, detection_distance)
	setup_avoid_ray(avoid_right, side * collision_clearance, move_direction, detection_distance)

	var center_blocked: bool = avoid_center.is_colliding()
	var left_blocked: bool = avoid_left.is_colliding()
	var right_blocked: bool = avoid_right.is_colliding()
	var blocked: bool = center_blocked or left_blocked or right_blocked

	if blocked:
		# Stick with one side while navigating the obstacle.
		if avoidance_side == 0 or (avoidance_time_left <= 0.0 and escape_time_left <= 0.0):
			if left_blocked and not right_blocked:
				avoidance_side = 1
			elif right_blocked and not left_blocked:
				avoidance_side = -1
			else:
				avoidance_side = -1 if randf() < 0.5 else 1
			avoidance_time_left = wall_follow_time

		if center_blocked:
			obstacle_normal = avoid_center.get_collision_normal()
		elif left_blocked:
			obstacle_normal = avoid_left.get_collision_normal()
		else:
			obstacle_normal = avoid_right.get_collision_normal()

		# Project along the wall instead of pushing directly into it.
		var tangent: Vector2 = Vector2(-obstacle_normal.y, obstacle_normal.x)
		var preferred_side: Vector2 = side * float(avoidance_side)
		if tangent.dot(preferred_side) < 0.0:
			tangent = -tangent

		var away: Vector2 = obstacle_normal * 0.4
		return (tangent + away).normalized()

	# Continue steering briefly so the enemy doesn't immediately
	# turn back into the same obstacle.
	if avoidance_time_left > 0.0 or escape_time_left > 0.0:
		var steer: Vector2 = side * float(avoidance_side)
		return (move_direction * 0.6 + steer * 0.8).normalized()

	avoidance_side = 0
	return move_direction


func setup_avoid_ray(ray: RayCast2D, offset: Vector2, direction: Vector2, distance: float) -> void:
	var world_start: Vector2 = global_position + offset
	ray.position = to_local(world_start)
	ray.target_position = to_local(world_start + direction * distance) - ray.position
	ray.force_raycast_update()


# ============================================
# STUCK RECOVERY
# ============================================

func update_stuck_detection(delta: float, intended_movement: bool) -> void:
	if not intended_movement:
		stuck_elapsed = 0.0
		stuck_position = global_position
		return

	stuck_elapsed += delta
	if stuck_elapsed < stuck_check_time:
		return

	if global_position.distance_to(stuck_position) < stuck_min_movement:
		# Try the opposite side, and give it time to get clear.
		avoidance_side = -avoidance_side if avoidance_side != 0 else 1
		avoidance_time_left = escape_time
		escape_time_left = escape_time

	stuck_elapsed = 0.0
	stuck_position = global_position


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
	call_deferred("drop_coins")

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
# ANIMATION STATE
# ============================================

func travel_to(state_name: String) -> void:
	if state_machine.get_current_node() != state_name:
		state_machine.travel(state_name)

	anim_tree.set("parameters/" + state_name + "/blend_position", facing_direction)

# ============================================
# COIN DROP
# ============================================

const COIN_SCENE = preload("res://Scenes/Coin.tscn")

@export var coin_drop_min: int = 1
@export var coin_drop_max: int = 1

# ============================================
# DROP COINS
# ============================================

func drop_coins() -> void:
	var amount: int = randi_range(coin_drop_min, coin_drop_max)
	var coins_container: Node2D = get_tree().current_scene.get_node("YSortWorld/Coins")

	for i in range(amount):
		var coin: Area2D = COIN_SCENE.instantiate()

		coins_container.add_child(coin)
		coin.global_position = global_position
		coin.scatter()
