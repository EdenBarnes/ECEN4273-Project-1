class_name Gun
extends Node2D


const BULLET_SCENE = preload("res://Scenes/bullet.tscn")


@export var weapon_data: WeaponData

@onready var gun_pivot: Node2D = $GunPivot
@onready var gun_visual: Node2D = $GunPivot/GunVisual
@onready var sprite: Sprite2D = $GunPivot/GunVisual/Sprite2D
@onready var muzzle: Marker2D = $GunPivot/GunVisual/MuzzlePosition
@onready var muzzle_flash: AnimatedSprite2D = $GunPivot/GunVisual/MuzzlePosition/MuzzleFlash
@onready var fire_timer: Timer = $FireTimer
@onready var reload_timer: Timer = $ReloadTimer
@onready var aim_cone: Node2D = $AimCone


var current_ammo: int = 0
var is_reloading: bool = false
var is_aiming: bool = false


func _ready() -> void:
	reload_timer.one_shot = true
	reload_timer.timeout.connect(_on_reload_finished)

	muzzle_flash.visible = false
	muzzle_flash.animation_finished.connect(_on_muzzle_flash_finished)

	if weapon_data:
		setup_weapon()


func setup_weapon() -> void:
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

	# Move aim cone to barrel tip
	aim_cone.position = gun_visual.position + muzzle.position


	# ============================================
	# MUZZLE FLASH
	# ============================================

	muzzle_flash.scale = Vector2.ONE * weapon_data.muzzle_flash_scale


	# ============================================
	# FIRE TIMER
	# ============================================

	fire_timer.one_shot = true
	fire_timer.wait_time = weapon_data.fire_rate


	# ============================================
	# RELOAD TIMER
	# ============================================

	reload_timer.wait_time = weapon_data.reload_time

	current_ammo = weapon_data.magazine_size


func set_aiming(value: bool) -> void:
	is_aiming = value


func get_current_spread() -> float:
	if weapon_data == null:
		return 0.0

	if is_aiming:
		return weapon_data.spread_angle * weapon_data.aim_spread_multiplier

	return weapon_data.spread_angle


func update_visual(direction: Vector2) -> void:
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


func can_shoot() -> bool:
	return (
		fire_timer.is_stopped()
		and not is_reloading
		and current_ammo > 0
	)


func shoot(direction: Vector2) -> void:
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


	# ============================================
	# FIRE COOLDOWN
	# ============================================

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
	# AUTO RELOAD WHEN EMPTY
	# ============================================

	if current_ammo <= 0:
		reload()


func reload() -> void:
	if weapon_data == null:
		return

	if is_reloading:
		return

	# Don't reload if magazine is already full
	if current_ammo >= weapon_data.magazine_size:
		return

	is_reloading = true

	reload_timer.wait_time = weapon_data.reload_time
	reload_timer.start()


func _on_reload_finished() -> void:
	current_ammo = weapon_data.magazine_size
	is_reloading = false


func play_muzzle_flash() -> void:
	muzzle_flash.visible = true
	muzzle_flash.frame = 0
	muzzle_flash.play("shoot")


func _on_muzzle_flash_finished() -> void:
	muzzle_flash.stop()
	muzzle_flash.visible = false


func spawn_bullet(direction: Vector2) -> void:
	var bullet = BULLET_SCENE.instantiate()

	get_tree().current_scene.add_child(bullet)


	# ============================================
	# BULLET SPAWN POSITION
	# ============================================

	bullet.global_position = muzzle.global_position


	# ============================================
	# BULLET SPREAD
	# ============================================

	var half_spread = get_current_spread() / 2.0

	var spread_degrees = randf_range(
		-half_spread,
		half_spread
	)

	var bullet_direction = direction.rotated(
		deg_to_rad(spread_degrees)
	)


	# ============================================
	# BULLET STATS
	# ============================================

	bullet.direction = bullet_direction
	bullet.speed = weapon_data.bullet_speed
	bullet.damage = weapon_data.damage
	bullet.pierce = weapon_data.pierce
	bullet.bounces = weapon_data.bounces
