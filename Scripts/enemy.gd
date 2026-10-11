extends CharacterBody2D


# ============================================
# DATA (assign BEFORE add_child so _ready sees it)
# ============================================

@export var data: EnemyData

signal health_changed(current_health: int, max_health: int)


# ============================================
# NODES
# ============================================

@onready var anim_tree: AnimationTree = $Sprite2D/AnimationTree
@onready var anim_player: AnimationPlayer = $Sprite2D/AnimationPlayer

@onready var hurt_timer: Timer = $HurtTimer
@onready var attack_timer: Timer = $AttackTimer

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_hitbox: Area2D = $AttackHitbox

@onready var raycast_center: RayCast2D = $RayCast2D_Center
@onready var raycast_left: RayCast2D = $RayCast2D_Left
@onready var raycast_right: RayCast2D = $RayCast2D_Right

# Fetched in _ready after the tree is (re)activated
var state_machine: AnimationNodeStateMachinePlayback


# ============================================
# ENEMY SETTINGS (filled from GameSettings + data)
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


# ============================================
# MOVEMENT
# ============================================

var movement_direction: Vector2 = Vector2.DOWN
var facing_direction: Vector2 = Vector2.DOWN

var is_locked: bool = false
var is_dead: bool = false

var player: CharacterBody2D = null

const FACING_MIN_SPEED: float = 10.0

# Obstacle avoidance side commitment
var avoid_side: float = 0.0        # +1 or -1 once committed, 0 = none
var avoid_clear_time: float = 0.0  # how long rays have been free
const AVOID_RELEASE_TIME: float = 0.5

# Boid update staggering
const BOID_INTERVAL: int = 3   # recompute boids every Nth physics frame

static var _enemy_cache: Array[Node] = []
static var _cache_frame: int = -1

var _boid_offset: int = randi() % BOID_INTERVAL   # spreads work across frames
var _sep := Vector2.ZERO
var _ali := Vector2.ZERO
var _coh := Vector2.ZERO


# ============================================
# HURT / STUN / FLASH
# ============================================

const FLASH_DURATION: float = 0.08

var next_stun_index: int = 0
var is_flashing: bool = false


# ============================================
# ATTACK
# ============================================

var player_hurtbox: Area2D = null


# ============================================
# ANIMATION CACHE
# ============================================

var _applied_state: String = ""
var _applied_facing: Vector2 = Vector2.ZERO


# ============================================
# COINS
# ============================================

const COIN_SCENE = preload("res://Scenes/Coin.tscn")


# ============================================
# READY
# ============================================

func _ready() -> void:
	apply_data()

	hurt_duration = GameSettings.ENEMY_HURT_DURATION
	attack_duration = GameSettings.ENEMY_ATTACK_DURATION

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

	# Animation (library was swapped in apply_data with the tree inactive)
	anim_tree.active = true
	state_machine = anim_tree["parameters/playback"]

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

	# Find player
	player = get_tree().get_first_node_in_group("player")

	# Rays
	raycast_center.enabled = true
	raycast_left.enabled = true
	raycast_right.enabled = true

	raycast_left.collide_with_areas = false
	raycast_center.collide_with_areas = false
	raycast_right.collide_with_areas = false

	raycast_left.collide_with_bodies = true
	raycast_center.collide_with_bodies = true
	raycast_right.collide_with_bodies = true


# ============================================
# APPLY DATA
# ============================================

func apply_data() -> void:
	if data == null:
		data = EnemyData.new()

	if data.use_wave_boss_stats:
		var wave: Waves2 = GameSettings.wave_Data
		speed = float(wave.BossSpeed)
		attack_distance = float(wave.Bossreach)
		attack_damage = wave.BossDam
		max_health = wave.Bosshealth
		scale = Vector2.ONE * float(wave.BossSize)
	else:
		speed = GameSettings.ENEMY_SPEED * data.speed_mult
		attack_distance = GameSettings.ENEMY_ATTACK_DISTANCE * data.attack_distance_mult
		attack_damage = int(round(GameSettings.ENEMY_ATTACK_DAMAGE * data.damage_mult))
		max_health = int(round(GameSettings.ENEMY_MAX_HEALTH * data.health_mult))
		scale = Vector2.ONE * GameSettings.ENEMY_SIZE * data.size_mult

	current_health = max_health

	# Swap in this type's animations. The tree only refers to animations by name,
	# so every library must use the same animation names.
	if data.animation_library != null:
		anim_tree.active = false

		if anim_player.has_animation_library(&""):
			anim_player.remove_animation_library(&"")
		anim_player.add_animation_library(&"", data.animation_library)


# ============================================
# PHYSICS
# ============================================

func _physics_process(delta: float) -> void:
	if is_locked:
		return

	if (Engine.get_physics_frames() + _boid_offset) % BOID_INTERVAL == 0:
		update_boids()

	var steering := Vector2.ZERO
	steering += _sep * separation_strength
	steering += _ali * alignment_strength
	steering += _coh * cohesion_strength
	steering += seek_goal() * seek_goal_strength

	update_rays()
	steering += avoid_obstacles() * obstacle_avoid_strength

	# Steering is unit-scale, so scale it to be meaningful
	var acceleration := steering * speed * 8.0   # tweak the 8.0 (turn responsiveness)
	velocity += acceleration * delta

	var health_speed_multiplier: float = float(current_health) / float(max_health)
	if health_speed_multiplier <= 0.25:
		health_speed_multiplier = 0.25
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

func get_enemies() -> Array[Node]:
	var frame := Engine.get_physics_frames()
	if _cache_frame != frame:
		_enemy_cache = get_tree().get_nodes_in_group("enemies")
		_cache_frame = frame
	return _enemy_cache


func update_boids() -> void:
	var my_pos := global_position
	var sep_r2 := separation_radius * separation_radius
	var ali_r2 := alignment_radius * alignment_radius
	var coh_r2 := cohesion_radius * cohesion_radius
	var max_r2 := maxf(sep_r2, maxf(ali_r2, coh_r2))

	var sep := Vector2.ZERO
	var vel_sum := Vector2.ZERO
	var pos_sum := Vector2.ZERO
	var ali_count := 0
	var coh_count := 0

	for other in get_enemies():
		if other == self:
			continue

		var other_pos: Vector2 = other.global_position
		var offset := my_pos - other_pos
		var d2 := offset.length_squared()

		if d2 > max_r2:
			continue

		if d2 < sep_r2:
			if d2 < 0.000001:
				# Exactly overlapping: push in a random direction so they split
				sep += Vector2.from_angle(randf() * TAU)
			else:
				var distance := sqrt(d2)
				var t := 1.0 - (distance / separation_radius)
				sep += offset / distance * t * t * 3.0

		if d2 < ali_r2:
			vel_sum += other.velocity
			ali_count += 1

		if d2 < coh_r2:
			pos_sum += other_pos
			coh_count += 1

	_sep = sep.limit_length(3.0)

	_ali = Vector2.ZERO
	if ali_count > 0:
		var avg_vel := vel_sum / ali_count
		if avg_vel.length_squared() > 0.001:
			_ali = (avg_vel - velocity) / speed

	_coh = Vector2.ZERO
	if coh_count > 0:
		var to_center := pos_sum / coh_count - my_pos
		if to_center.length_squared() > 0.001:
			_coh = to_center.normalized()


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

	if data.flash_on_hit:
		flash()

	# Death
	if current_health <= 0:
		current_health = 0
		die()
		return

	var should_stun: bool = false

	# Threshold stuns (e.g. boss at 75%, 50%, 25%)
	while next_stun_index < data.stun_thresholds.size():
		var threshold_health: float = max_health * data.stun_thresholds[next_stun_index]

		if previous_health > threshold_health and current_health <= threshold_health:
			should_stun = true
			next_stun_index += 1
		else:
			break

	# Regular enemies stun on every hit
	if data.stun_on_every_hit:
		should_stun = true

	if should_stun:
		stun()


func stun() -> void:
	is_locked = true
	velocity = Vector2.ZERO

	travel_to("hurt")
	hurt_timer.start()


func flash() -> void:
	if is_flashing:
		return

	is_flashing = true
	$Sprite2D.modulate = Color(2.0, 2.0, 2.0, 1.0)

	await get_tree().create_timer(FLASH_DURATION).timeout

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
	player_hurtbox = null
	call_deferred("drop_coins")

	# Disable collisions
	collision_shape.set_deferred("disabled", true)
	attack_hitbox.set_deferred("monitoring", false)
	attack_hitbox.set_deferred("monitorable", false)

	# Notify wave manager immediately
	var wave_manager: Node = get_tree().get_first_node_in_group("wave_manager")
	var callback: String = "on_boss_died" if data.is_boss else "on_enemy_died"

	if wave_manager != null and wave_manager.has_method(callback):
		wave_manager.call(callback)

	# Death animation
	travel_to("death")

	# Leave corpse for 5 seconds
	await get_tree().create_timer(5.0).timeout

	queue_free()


# ============================================
# ANIMATION STATE
# ============================================

func travel_to(state_name: String) -> void:
	if state_machine.get_current_node() != state_name:
		state_machine.travel(state_name)

	# Only touch the tree parameter when something actually changed
	if state_name != _applied_state or facing_direction != _applied_facing:
		anim_tree.set("parameters/" + state_name + "/blend_position", facing_direction)
		_applied_state = state_name
		_applied_facing = facing_direction


# ============================================
# DROP COINS
# ============================================

func drop_coins() -> void:
	var amount: int = randi_range(data.coin_drop_min, data.coin_drop_max)
	var coins_container: Node2D = get_tree().current_scene.get_node("YSortWorld/Coins")

	for i in range(amount):
		var coin: Area2D = COIN_SCENE.instantiate()

		coins_container.add_child(coin)
		coin.global_position = global_position
		coin.scatter()
