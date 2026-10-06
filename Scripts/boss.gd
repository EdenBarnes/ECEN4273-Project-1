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

@onready var raycast_center: RayCast2D = $RayCast2D_Center
@onready var raycast_left: RayCast2D = $RayCast2D_Left
@onready var raycast_right: RayCast2D = $RayCast2D_Right


# ============================================
# BOSS SETTINGS
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

var alignment_radius: float
var alignment_strength: float

var cohesion_radius: float
var cohesion_strength: float

var seek_goal_strength: float
var seek_goal_radius: float
var seek_far_min: float
var seek_falloff: float

var obstacle_avoid_distance: float
var obstacle_avoid_strength: float

var next_stun_threshold: float = 0.75

var flash_duration: float = 0.08
var is_flashing: bool = false

signal health_changed(current_health: int, max_health: int)


# ============================================
# MOVEMENT
# ============================================

var movement_direction: Vector2 = Vector2.DOWN
var facing_direction: Vector2 = Vector2.DOWN

var is_locked: bool = false
var is_dead: bool = false

var player: CharacterBody2D = null

const FACING_MIN_SPEED: float = 10.0

var avoid_side: float = 0.0        # +1 or -1 once committed, 0 = none
var avoid_clear_time: float = 0.0  # how long rays have been free
const AVOID_RELEASE_TIME: float = 0.5


# ============================================
# ATTACK
# ============================================

var player_hurtbox: Area2D = null


# ============================================
# READY
# ============================================

func _ready() -> void:
	# Current wave
	var wave_data: Waves2 = GameSettings.wave_Data

	# Boss settings
	speed = float(wave_data.BossSpeed)
	hurt_duration = GameSettings.ENEMY_HURT_DURATION

	attack_distance = float(wave_data.Bossreach)
	attack_damage = wave_data.BossDam
	attack_duration = GameSettings.ENEMY_ATTACK_DURATION

	max_health = wave_data.Bosshealth
	current_health = max_health

	# Boss size
	scale = Vector2.ONE * float(wave_data.BossSize)

	separation_radius = GameSettings.ENEMY_SEPARATION_RADIUS
	separation_strength = GameSettings.ENEMY_SEPARATION_STRENGTH

	alignment_radius = GameSettings.ENEMY_ALIGNMENT_RADIUS
	alignment_strength = GameSettings.ENEMY_ALIGNMENT_STRENGTH

	cohesion_radius = GameSettings.ENEMY_COHESION_RADIUS
	cohesion_strength = GameSettings.ENEMY_COHESION_STRENGTH

	seek_goal_strength = GameSettings.ENEMY_SEEK_GOAL_STRENGTH
	seek_goal_radius = GameSettings.ENEMY_SEEK_GOAL_RADIUS
	seek_far_min = GameSettings.ENEMY_SEEK_FAR_MIN
	seek_falloff = GameSettings.ENEMY_SEEK_FALLOFF

	obstacle_avoid_distance = GameSettings.ENEMY_OBSTACLE_AVOID_DISTANCE
	obstacle_avoid_strength = GameSettings.ENEMY_OBSTACLE_AVOID_STRENGTH

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

	# Obstacle avoidance rays
	raycast_left.enabled = true
	raycast_center.enabled = true
	raycast_right.enabled = true

	raycast_left.collide_with_areas = false
	raycast_center.collide_with_areas = false
	raycast_right.collide_with_areas = false

	raycast_left.collide_with_bodies = true
	raycast_center.collide_with_bodies = true
	raycast_right.collide_with_bodies = true

	# Find player
	player = get_tree().get_first_node_in_group("player")


# ============================================
# PHYSICS
# ============================================

func _physics_process(delta: float) -> void:
	if is_locked:
		return

	var steering := Vector2.ZERO

	steering += separation() * separation_strength
	steering += alignment() * alignment_strength
	steering += cohesion() * cohesion_strength
	steering += seek_goal() * seek_goal_strength

	update_rays()
	steering += avoid_obstacles() * obstacle_avoid_strength

	# Steering is unit-scale, so scale it to be meaningful
	var acceleration := steering * speed * 8.0   # tweak the 8.0 (turn responsiveness)
	velocity += acceleration * delta

	var health_speed_multiplier: float = float(current_health) / float(max_health)
	velocity = velocity.limit_length(speed * health_speed_multiplier)

	if velocity.length() > FACING_MIN_SPEED:
		facing_direction = velocity.normalized()
		movement_direction = facing_direction

		travel_to("walk")
	else:
		travel_to("idle")

	move_and_slide()


# ============================================
# AI - BOIDS
# ============================================

func separation() -> Vector2:
	var force := Vector2.ZERO

	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue

		var offset: Vector2 = global_position - other.global_position
		var distance := offset.length()

		if distance < 0.001:
			# Exactly overlapping: push in a random direction so they split
			force += Vector2.from_angle(randf() * TAU)
		elif distance < separation_radius:
			# Stronger the closer they are (quadratic falloff), NOT averaged
			var t := 1.0 - (distance / separation_radius)
			force += offset.normalized() * t * t * 3.0

	return force.limit_length(3.0)


func alignment() -> Vector2:
	var average_velocity := Vector2.ZERO
	var count := 0

	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		if global_position.distance_to(other.global_position) < alignment_radius:
			average_velocity += other.velocity
			count += 1

	if count == 0:
		return Vector2.ZERO

	average_velocity /= count
	if average_velocity.length_squared() < 0.001:
		return Vector2.ZERO

	# Compare as fractions of speed so it's unit-scale
	return (average_velocity - velocity) / speed


func cohesion() -> Vector2:
	var center := Vector2.ZERO
	var count := 0

	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		if global_position.distance_to(other.global_position) < cohesion_radius:
			center += other.global_position
			count += 1

	if count == 0:
		return Vector2.ZERO

	center /= count
	var direction := center - global_position
	if direction.length_squared() < 0.001:
		return Vector2.ZERO

	return direction.normalized()

func seek_goal() -> Vector2:
	if player == null:
		return Vector2.ZERO

	var direction := player.global_position - global_position
	var distance := direction.length()

	if distance <= attack_distance / 2.0:
		# Brake smoothly when in range
		return -velocity / speed

	# Full strength inside the radius, fading (but never zero) beyond it
	var strength := 1.0
	if distance > seek_goal_radius:
		strength = maxf(seek_far_min, pow(seek_goal_radius / distance, seek_falloff))

	var desired_velocity := direction.normalized() * speed
	return (desired_velocity - velocity) / speed * strength

# ============================================
# OBSTACLE AVOIDANCE
# ============================================

func update_rays() -> void:
	var direction := Vector2.ZERO
	if player != null:
		direction = player.global_position - global_position
	if direction.length_squared() < 0.001:
		direction = velocity
	if direction.length_squared() < 0.001:
		return

	direction = direction.normalized()
	var reach := obstacle_avoid_distance / scale.x

	raycast_center.target_position = direction * reach
	raycast_left.target_position = direction.rotated(deg_to_rad(-35)) * reach
	raycast_right.target_position = direction.rotated(deg_to_rad(35)) * reach


func avoid_obstacles() -> Vector2:
	var force := Vector2.ZERO
	var any_hit := false

	var to_player := Vector2.ZERO
	if player != null:
		to_player = (player.global_position - global_position).normalized()

	for ray in [raycast_center, raycast_left, raycast_right]:
		if not ray.is_colliding():
			continue
		any_hit = true

		var point: Vector2 = ray.get_collision_point()
		var normal: Vector2 = ray.get_collision_normal()
		var distance := global_position.distance_to(point)
		var strength := 1.0 - clampf(distance / obstacle_avoid_distance, 0.0, 1.0)

		var tangent := Vector2(-normal.y, normal.x)

		# Commit to a side the first time we hit something
		if avoid_side == 0.0:
			var d := tangent.dot(to_player)
			if absf(d) > 0.1:
				avoid_side = signf(d)
			else:
				# Head-on: pick based on current velocity, else randomly
				var v := tangent.dot(velocity)
				avoid_side = signf(v) if absf(v) > 1.0 else (1.0 if randf() < 0.5 else -1.0)

		force += (tangent * avoid_side * 0.9 + normal * 0.2) * strength

	# Release the commitment only after being clear for a while
	var dt := get_physics_process_delta_time()
	if any_hit:
		avoid_clear_time = 0.0
	else:
		avoid_clear_time += dt
		if avoid_clear_time > AVOID_RELEASE_TIME:
			avoid_side = 0.0

	return force.limit_length(2.0)


# ============================================
# TAKE DAMAGE
# ============================================

func take_damage(amount: int) -> void:
	if is_dead:
		return

	var previous_health: int = current_health
	current_health -= amount

	health_changed.emit(current_health, max_health)

	# Flash every hit
	flash_boss()

	# Death
	if current_health <= 0:
		current_health = 0
		die()
		return

	# Check 75%, 50%, and 25% stun thresholds
	var should_stun: bool = false

	while next_stun_threshold > 0.0:
		var threshold_health: float = max_health * next_stun_threshold

		if previous_health > threshold_health and current_health <= threshold_health:
			should_stun = true
			next_stun_threshold -= 0.25
		else:
			break

	if should_stun:
		stun_boss()


# ============================================
# STUN BOSS
# ============================================

func stun_boss() -> void:
	is_locked = true
	velocity = Vector2.ZERO

	travel_to("hurt")
	hurt_timer.start()


# ============================================
# FLASH BOSS
# ============================================

func flash_boss() -> void:
	if is_flashing:
		return

	is_flashing = true
	$Sprite2D.modulate = Color(2.0, 2.0, 2.0, 1.0)

	await get_tree().create_timer(flash_duration).timeout

	if not is_dead:
		$Sprite2D.modulate = Color.WHITE

	is_flashing = false


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
	remove_from_group("enemies")
	velocity = Vector2.ZERO
	call_deferred("drop_coins")

	# Disable movement collision
	collision_shape.set_deferred("disabled", true)

	# Disable attack/hurt hitbox
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox.set_deferred("monitorable", false)

	player_hurtbox = null

	travel_to("death")

	# Notify WaveManager immediately
	var wave_manager: Node = get_tree().get_first_node_in_group("wave_manager")

	if wave_manager != null and wave_manager.has_method("on_boss_died"):
		wave_manager.on_boss_died()

	# Leave corpse for 5 seconds
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

@export var coin_drop_min: int = 100
@export var coin_drop_max: int = 100

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
