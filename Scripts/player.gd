extends CharacterBody2D

# ============================================
# PLAYER NODES
# ============================================

@onready var anim_tree: AnimationTree = $Sprite2D/AnimationTree
@onready var anim_player: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var state_machine: AnimationNodeStateMachinePlayback = anim_tree["parameters/playback"]

@onready var hurt_timer: Timer = $HurtTimer
@onready var invulnerability_timer: Timer = $InvulnerabilityTimer

@onready var sprint_cooldown: AnimatedSprite2D = get_tree().current_scene.get_node("HUD/HUDRoot/SprintCooldown")

signal health_changed(current_health: int, max_health: int)

# ============================================
# WEAPON NODES
# ============================================

@onready var weapon_holder: Node2D = $WeaponHolder
@onready var current_gun = $WeaponHolder/Gun
@onready var aim_cone: Node2D = $WeaponHolder/Gun/AimCone

# ============================================
# STARTING WEAPON
# ============================================

@export_category("Starting Weapon")
@export var starting_weapon: WeaponData

# ============================================
# WEAPON INVENTORY
# ============================================

var weapon_slot_1: WeaponInstance = null
var weapon_slot_2: WeaponInstance = null
var current_weapon_slot: int = 0

# ============================================
# PLAYER STATS
# ============================================

var speed: float = 50.0
var hurt_duration: float = 0.5
var invulnerability_duration: float = 2.0

var base_max_health: int = 100
var max_health: int = 100
var current_health: int = 100

# ============================================
# PERKS
# ============================================

var equipped_perks: Array[String] = []

# ============================================
# DASH
# ============================================

var dash_time: float = 0.0
var dash_recharge_time: float = 0.0
var current_dashes: int = 0

var is_dashing: bool = false
var dash_locked: bool = false

var dash_direction: Vector2 = Vector2.DOWN

# ============================================
# PLAYER STATE
# ============================================

var movement_direction := Vector2.DOWN
var facing_direction := Vector2.DOWN

var is_locked := false
var is_dead := false

# ============================================
# READY
# ============================================

func _ready() -> void:

	# ============================================
	# LOAD PLAYER SETTINGS
	# ============================================

	speed = GameSettings.PLAYER_SPEED
	hurt_duration = GameSettings.PLAYER_HURT_DURATION
	invulnerability_duration = GameSettings.PLAYER_INVULNERABILITY_DURATION

	base_max_health = GameSettings.PLAYER_MAX_HEALTH
	max_health = base_max_health
	current_health = max_health

	scale = Vector2.ONE * GameSettings.PLAYER_SIZE

	current_dashes = GameSettings.PLAYER_MAX_DASHES

	# ============================================
	# SPRINT COOLDOWN HUD
	# ============================================

	sprint_cooldown.visible = true
	sprint_cooldown.stop()
	sprint_cooldown.animation = "recharge"

	var frame_count: int = sprint_cooldown.sprite_frames.get_frame_count("recharge")

	if frame_count > 0:
		sprint_cooldown.frame = frame_count - 1

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
	# STARTING INVENTORY
	# ============================================

	if starting_weapon:
		weapon_slot_1 = WeaponInstance.new(starting_weapon)

	weapon_slot_2 = null

	if weapon_slot_1:
		equip_weapon(1)

	# ============================================
	# PLAYER START POSITION
	# ============================================

	global_position = Vector2(785, 330)

# ============================================
# PHYSICS PROCESS
# ============================================

func _physics_process(delta: float) -> void:
	if is_locked:
		return

	# ============================================
	# WEAPON SWITCHING
	# ============================================

	if Input.is_action_just_pressed("weapon_1"):
		equip_weapon(1)

	if Input.is_action_just_pressed("weapon_2"):
		equip_weapon(2)

	if Input.is_action_just_pressed("weapon_next"):
		switch_weapon(1)

	if Input.is_action_just_pressed("weapon_previous"):
		switch_weapon(-1)

	# ============================================
	# AIM INPUT
	# ============================================

	var is_aiming: bool = Input.is_action_pressed("aim")
	current_gun.set_aiming(is_aiming)

	# ============================================
	# MOVEMENT INPUT
	# ============================================

	var input_vector: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	# ============================================
	# DASH
	# ============================================

	update_dash(delta)

	# ============================================
	# AIMING
	# ============================================

	var mouse_pos: Vector2 = get_global_mouse_position()
	facing_direction = (mouse_pos - global_position).normalized()

	weapon_holder.rotation = facing_direction.angle()
	current_gun.update_visual(facing_direction)

	if facing_direction.y < -0.5:
		weapon_holder.show_behind_parent = true
	else:
		weapon_holder.show_behind_parent = false

	# ============================================
	# AIM CONE
	# ============================================

	if current_gun.weapon_data:
		aim_cone.spread_angle = current_gun.get_current_spread()
		aim_cone.cone_length = current_gun.weapon_data.aim_cone_length
		aim_cone.cone_start_distance = current_gun.weapon_data.aim_cone_start_distance

	# ============================================
	# MOVEMENT SPEED
	# ============================================

	var current_speed: float = speed

	if is_dashing:
		current_speed *= GameSettings.PLAYER_DASH_MULTIPLIER

	if is_aiming and current_gun.weapon_data:
		current_speed *= current_gun.weapon_data.aim_move_speed_multiplier

	# ============================================
	# MOVEMENT
	# ============================================

	if input_vector != Vector2.ZERO:
		movement_direction = input_vector.normalized()
		velocity = movement_direction * current_speed
		travel_to("walk")

	elif is_dashing:
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

	# ============================================
	# RELOADING
	# ============================================

	if Input.is_action_just_pressed("reload"):
		current_gun.reload()

	move_and_slide()

# ============================================
# DASH
# ============================================

func update_dash(delta: float) -> void:
	var wants_to_dash: bool = Input.is_action_pressed("sprint")

	# ============================================
	# RECHARGE DASHES
	# ============================================

	if current_dashes < GameSettings.PLAYER_MAX_DASHES:
		dash_recharge_time += delta

		var recharge_progress: float = dash_recharge_time / GameSettings.PLAYER_DASH_RECHARGE
		recharge_progress = clampf(recharge_progress, 0.0, 1.0)

		var frame_count: int = sprint_cooldown.sprite_frames.get_frame_count("recharge")
		var recharge_frame: int = floori(recharge_progress * float(frame_count - 1))

		sprint_cooldown.animation = "recharge"
		sprint_cooldown.frame = recharge_frame

		if dash_recharge_time >= GameSettings.PLAYER_DASH_RECHARGE:
			dash_recharge_time = 0.0
			current_dashes += 1

			if current_dashes > GameSettings.PLAYER_MAX_DASHES:
				current_dashes = GameSettings.PLAYER_MAX_DASHES

			if current_dashes >= GameSettings.PLAYER_MAX_DASHES:
				sprint_cooldown.frame = frame_count - 1

	else:
		dash_recharge_time = 0.0

		var frame_count: int = sprint_cooldown.sprite_frames.get_frame_count("recharge")

		sprint_cooldown.animation = "recharge"

		if frame_count > 0:
			sprint_cooldown.frame = frame_count - 1

	# ============================================
	# RELEASE DASH BUTTON
	# ============================================

	if not wants_to_dash:
		dash_locked = false

	# ============================================
	# CURRENT DASH
	# ============================================

	if is_dashing:
		dash_time -= delta

		if dash_time <= 0.0:
			dash_time = 0.0
			is_dashing = false

			if current_dashes <= 0:
				dash_locked = true

		return

	# ============================================
	# START NEXT DASH
	# ============================================

	if wants_to_dash and current_dashes > 0 and not dash_locked:
		start_dash()

# ============================================
# START DASH
# ============================================

func start_dash() -> void:
	current_dashes -= 1

	is_dashing = true
	dash_time = GameSettings.PLAYER_DASH_DURATION

	dash_direction = movement_direction

# ============================================
# EQUIP WEAPON
# ============================================

func equip_weapon(slot: int) -> void:
	var new_weapon: WeaponInstance = null

	if slot == 1:
		new_weapon = weapon_slot_1
	elif slot == 2:
		new_weapon = weapon_slot_2
	else:
		return

	if new_weapon == null:
		return

	if current_weapon_slot == slot:
		return

	if current_weapon_slot != 0:
		current_gun.save_weapon_state()

	current_weapon_slot = slot
	current_gun.equip_weapon(new_weapon)

# ============================================
# WEAPON SWITCHING
# ============================================

func switch_weapon(_direction: int) -> void:
	if current_weapon_slot == 0:
		if weapon_slot_1 != null:
			equip_weapon(1)
		elif weapon_slot_2 != null:
			equip_weapon(2)
		return

	if weapon_slot_1 != null and weapon_slot_2 != null:
		if current_weapon_slot == 1:
			equip_weapon(2)
		elif current_weapon_slot == 2:
			equip_weapon(1)
		return

	if weapon_slot_1 != null:
		equip_weapon(1)
		return

	if weapon_slot_2 != null:
		equip_weapon(2)
		return

# ============================================
# ADD WEAPON TO INVENTORY
# ============================================

func add_weapon(new_weapon_data: WeaponData) -> bool:
	if new_weapon_data == null:
		return false

	var held_weapon: WeaponInstance = get_current_weapon()

	if held_weapon != null:
		if held_weapon.weapon_data == new_weapon_data:
			return false

	if weapon_slot_1 == null:
		weapon_slot_1 = WeaponInstance.new(new_weapon_data)
		apply_perks(equipped_perks)
		equip_weapon(1)
		return true

	if weapon_slot_2 == null:
		weapon_slot_2 = WeaponInstance.new(new_weapon_data)
		apply_perks(equipped_perks)
		equip_weapon(2)
		return true

	var new_weapon_instance: WeaponInstance = WeaponInstance.new(new_weapon_data)

	if current_weapon_slot == 1:
		weapon_slot_1 = new_weapon_instance
		apply_perks(equipped_perks)
		current_weapon_slot = 0
		equip_weapon(1)
		return true

	elif current_weapon_slot == 2:
		weapon_slot_2 = new_weapon_instance
		apply_perks(equipped_perks)
		current_weapon_slot = 0
		equip_weapon(2)
		return true

	return false

# ============================================
# GET CURRENT WEAPON
# ============================================

func get_current_weapon() -> WeaponInstance:
	if current_weapon_slot == 1:
		return weapon_slot_1

	if current_weapon_slot == 2:
		return weapon_slot_2

	return null

# ============================================
# PERK SYSTEM
# ============================================

func apply_perks(perks: Array[String]) -> void:
	equipped_perks = perks.duplicate()

	var old_max_health: int = max_health

	max_health = base_max_health

	if weapon_slot_1 != null:
		weapon_slot_1.reset_perk_bonuses()

	if weapon_slot_2 != null:
		weapon_slot_2.reset_perk_bonuses()

	for perk_name: String in equipped_perks:
		apply_single_perk(perk_name)

	if current_health > max_health:
		current_health = max_health

	if max_health > old_max_health:
		current_health += max_health - old_max_health
		current_health = mini(current_health, max_health)

	health_changed.emit(current_health, max_health)

	if current_gun != null:
		current_gun.refresh_perk_stats()


func apply_single_perk(perk_name: String) -> void:
	match perk_name:
		"Ammo_Coin":
			apply_ammo_perk()

		"Health_Coin":
			apply_health_perk()

		"Dmg_Coin":
			apply_damage_perk()

		"Reload_Coin":
			apply_reload_perk()

		"Aim_Coin":
			apply_aim_perk()

		"Firerate_Coin":
			apply_fire_rate_perk()

		"Bounce_Coin":
			apply_bounce_perk()

		"Bullet_Coin":
			apply_bullet_perk()

		"Pierce_Coin":
			apply_pierce_perk()

# ============================================
# COMMON PERKS
# ============================================

func apply_ammo_perk() -> void:
	if weapon_slot_1 != null:
		weapon_slot_1.magazine_multiplier *= 1.20

	if weapon_slot_2 != null:
		weapon_slot_2.magazine_multiplier *= 1.20


func apply_health_perk() -> void:
	max_health = roundi(float(max_health) * 1.20)


func apply_damage_perk() -> void:
	if weapon_slot_1 != null:
		weapon_slot_1.damage_multiplier *= 1.20

	if weapon_slot_2 != null:
		weapon_slot_2.damage_multiplier *= 1.20

# ============================================
# EPIC PERKS
# ============================================

func apply_reload_perk() -> void:
	if weapon_slot_1 != null:
		weapon_slot_1.reload_multiplier *= 0.80

	if weapon_slot_2 != null:
		weapon_slot_2.reload_multiplier *= 0.80


func apply_aim_perk() -> void:
	if weapon_slot_1 != null:
		weapon_slot_1.aim_multiplier *= 0.80

	if weapon_slot_2 != null:
		weapon_slot_2.aim_multiplier *= 0.80


func apply_fire_rate_perk() -> void:
	if weapon_slot_1 != null:
		weapon_slot_1.fire_rate_multiplier *= 0.80

	if weapon_slot_2 != null:
		weapon_slot_2.fire_rate_multiplier *= 0.80

# ============================================
# LEGENDARY PERKS
# ============================================

func apply_bounce_perk() -> void:
	if weapon_slot_1 != null:
		weapon_slot_1.bounce_bonus += 1

	if weapon_slot_2 != null:
		weapon_slot_2.bounce_bonus += 1


func apply_bullet_perk() -> void:
	if weapon_slot_1 != null:
		weapon_slot_1.bullets_per_shot_bonus += 1

	if weapon_slot_2 != null:
		weapon_slot_2.bullets_per_shot_bonus += 1


func apply_pierce_perk() -> void:
	if weapon_slot_1 != null:
		weapon_slot_1.pierce_bonus += 1

	if weapon_slot_2 != null:
		weapon_slot_2.pierce_bonus += 1

# ============================================
# DAMAGE
# ============================================

func take_damage(amount: int) -> void:
	if is_dead:
		return

	if not invulnerability_timer.is_stopped():
		return

	if is_dashing:
		var immunity_roll: float = randf()

		if immunity_roll <= GameSettings.PLAYER_DASH_IMMUNITY_CHANCE:
			return

	current_health -= amount
	health_changed.emit(current_health, max_health)

	invulnerability_timer.start(invulnerability_duration)

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
# DEATH
# ============================================

func die() -> void:
	is_locked = true
	is_dead = true

	velocity = Vector2.ZERO

	travel_to("death")

	await get_tree().create_timer(5.0).timeout

	queue_free()

# ============================================
# ANIMATION
# ============================================

func travel_to(state_name: String) -> void:
	if state_machine.get_current_node() != state_name:
		state_machine.travel(state_name)

	anim_tree.set(
		"parameters/" + state_name + "/blend_position",
		facing_direction
	)

# ============================================
# COINS
# ============================================

var coins: int = 0

signal coins_changed(current_coins: int)


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func remove_coins(amount: int) -> bool:
	if coins < amount:
		return false

	coins -= amount
	coins_changed.emit(coins)

	return true


func get_coins() -> int:
	return coins

# ============================================
# HEALING
# ============================================

func heal(percent: float) -> bool:
	if is_dead:
		return false

	if current_health >= max_health:
		return false

	var heal_amount: int = ceili(float(max_health) * percent)

	current_health += heal_amount
	current_health = mini(current_health, max_health)

	health_changed.emit(current_health, max_health)

	return true
