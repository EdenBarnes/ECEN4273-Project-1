class_name Gun
extends Node2D


const BULLET_SCENE = preload("res://Scenes/bullet.tscn")


# ============================================
# CURRENT WEAPON
# ============================================

var weapon_instance: WeaponInstance = null
var weapon_data: WeaponData = null

# ============================================
# NODES
# ============================================

@onready var gun_pivot: Node2D = $GunPivot
@onready var gun_visual: Node2D = $GunPivot/GunVisual
@onready var sprite: Sprite2D = $GunPivot/GunVisual/Sprite2D
@onready var muzzle: Marker2D = $GunPivot/GunVisual/MuzzlePosition
@onready var muzzle_flash: AnimatedSprite2D = $GunPivot/GunVisual/MuzzlePosition/MuzzleFlash

@onready var fire_timer: Timer = $FireTimer
@onready var reload_timer: Timer = $ReloadTimer
@onready var aim_cone: Node2D = $AimCone

@onready var bullets_container: Node2D = (
	get_tree().current_scene.get_node("YSortWorld/Bullets")
)

# ============================================
# WEAPON STATE
# ============================================

var current_ammo: int = 0
var is_reloading: bool = false
var is_aiming: bool = false


func _ready() -> void:
	fire_timer.one_shot = true

	reload_timer.one_shot = true
	reload_timer.timeout.connect(_on_reload_finished)

	muzzle_flash.visible = false
	muzzle_flash.animation_finished.connect(_on_muzzle_flash_finished)


# ============================================
# EQUIP WEAPON
# ============================================

func equip_weapon(new_weapon: WeaponInstance) -> void:
	if new_weapon == null:
		return

	# Save the old weapon before changing.
	save_weapon_state()

	# Cancel any reload/fire cooldown from the old weapon.
	reload_timer.stop()
	fire_timer.stop()

	is_reloading = false

	# Equip the new weapon instance.
	weapon_instance = new_weapon
	weapon_data = weapon_instance.weapon_data

	# Restore this weapon's ammo.
	current_ammo = weapon_instance.current_ammo

	setup_weapon()


# ============================================
# SAVE CURRENT WEAPON
# ============================================

func save_weapon_state() -> void:
	if weapon_instance == null:
		return

	weapon_instance.current_ammo = current_ammo


# ============================================
# SETUP WEAPON
# ============================================

func setup_weapon() -> void:
	if weapon_instance == null:
		return

	if weapon_data == null:
		return


	# ============================================
	# WEAPON TEXTURE
	# ============================================

	if weapon_data.weapon_texture:
		sprite.texture = weapon_data.weapon_texture


	# ============================================
	# WEAPON SCALE
	# ============================================

	scale = Vector2.ONE * weapon_data.gun_scale


	# ============================================
	# WEAPON POSITIONING
	# ============================================

	gun_pivot.position = Vector2.ZERO

	gun_visual.position = weapon_data.gun_visual_offset

	muzzle.position = weapon_data.muzzle_position

	# Move the cone to the barrel tip.
	aim_cone.position = gun_visual.position + muzzle.position


	# ============================================
	# MUZZLE FLASH
	# ============================================

	muzzle_flash.scale = Vector2.ONE * weapon_data.muzzle_flash_scale


	# ============================================
	# FIRE TIMER
	# ============================================

	# Uses the WeaponInstance version so buffs
	# can modify fire rate.
	fire_timer.wait_time = weapon_instance.get_fire_rate()


	# ============================================
	# RELOAD TIMER
	# ============================================

	reload_timer.wait_time = weapon_data.reload_time


# ============================================
# AIMING
# ============================================

func set_aiming(value: bool) -> void:
	is_aiming = value


func get_current_spread() -> float:
	if weapon_instance == null:
		return 0.0

	# Get spread including any buffs.
	var spread := weapon_instance.get_spread()

	if is_aiming:
		spread *= weapon_data.aim_spread_multiplier

	return spread


# ============================================
# GUN VISUAL / FLIPPING
# ============================================

func update_visual(direction: Vector2) -> void:
	if weapon_data == null:
		return

	if direction.x < 0:
		gun_pivot.scale.y = -1.0

		aim_cone.position = Vector2(
			gun_visual.position.x + muzzle.position.x,
			-(gun_visual.position.y + muzzle.position.y)
		)

	else:
		gun_pivot.scale.y = 1.0

		aim_cone.position = Vector2(
			gun_visual.position.x + muzzle.position.x,
			gun_visual.position.y + muzzle.position.y
		)


# ============================================
# CAN SHOOT
# ============================================

func can_shoot() -> bool:
	return (
		weapon_instance != null
		and fire_timer.is_stopped()
		and not is_reloading
		and current_ammo > 0
	)


# ============================================
# SHOOT
# ============================================

func shoot(direction: Vector2) -> void:
	if weapon_instance == null:
		return

	if weapon_data == null:
		return

	if is_reloading:
		return

	if current_ammo <= 0:
		reload()
		return

	if not can_shoot():
		return


	# ============================================
	# USE AMMO
	# ============================================

	current_ammo -= 1

	# Immediately save ammo to this weapon instance.
	weapon_instance.current_ammo = current_ammo


	# ============================================
	# FIRE COOLDOWN
	# ============================================

	fire_timer.wait_time = weapon_instance.get_fire_rate()
	fire_timer.start()


	# ============================================
	# MUZZLE FLASH
	# ============================================

	play_muzzle_flash()


	# ============================================
	# SPAWN BULLETS
	# ============================================

	for i in range(weapon_data.bullets_per_shot):
		spawn_bullet(direction)


	# ============================================
	# AUTO RELOAD
	# ============================================

	if current_ammo <= 0:
		reload()


# ============================================
# RELOAD
# ============================================

func reload() -> void:
	if weapon_instance == null:
		return

	if weapon_data == null:
		return

	if is_reloading:
		return

	# Don't reload a full magazine.
	if current_ammo >= weapon_instance.get_magazine_size():
		return

	is_reloading = true

	reload_timer.wait_time = weapon_data.reload_time
	reload_timer.start()


func _on_reload_finished() -> void:
	if weapon_instance == null:
		return

	current_ammo = weapon_instance.get_magazine_size()

	# Save the new ammo amount.
	weapon_instance.current_ammo = current_ammo

	is_reloading = false


# ============================================
# MUZZLE FLASH
# ============================================

func play_muzzle_flash() -> void:
	muzzle_flash.visible = true
	muzzle_flash.frame = 0
	muzzle_flash.play("shoot")


func _on_muzzle_flash_finished() -> void:
	muzzle_flash.stop()
	muzzle_flash.visible = false


# ============================================
# SPAWN BULLET
# ============================================

func spawn_bullet(direction: Vector2) -> void:
	if weapon_instance == null:
		return

	var bullet = BULLET_SCENE.instantiate()

	# Add bullet to the Y-sorted bullet container.
	bullets_container.add_child(bullet)


	# ============================================
	# BULLET SPAWN POSITION
	# ============================================

	bullet.global_position = muzzle.global_position


	# ============================================
	# BULLET SPREAD
	# ============================================

	var half_spread: float = (
		get_current_spread() / 2.0
	)

	var spread_degrees: float = randf_range(
		-half_spread,
		half_spread
	)

	var bullet_direction: Vector2 = (
		direction.rotated(
			deg_to_rad(spread_degrees)
		)
	)


	# ============================================
	# BULLET STATS
	# ============================================

	bullet.direction = bullet_direction

	# These now use the WeaponInstance so
	# buffs stay attached to this specific gun.
	bullet.speed = weapon_instance.get_bullet_speed()
	bullet.damage = weapon_instance.get_damage()
	bullet.pierce = weapon_instance.get_pierce()
	bullet.bounces = weapon_instance.get_bounces()
