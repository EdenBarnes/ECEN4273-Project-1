class_name WeaponData
extends Resource

@export_category("Weapon")
@export var weapon_name: String = "Pistol"
@export var weapon_texture: Texture2D

@export_category("Shooting")
@export var damage: int = 50
@export var bullet_speed: float = 400.0
@export var fire_rate: float = 0.5
@export var bullets_per_shot: int = 1
@export var pierce: int = 0
@export var bounces: int = 0

@export_category("Ammo")
@export var magazine_size: int = 12
@export var reload_time: float = 1.2

@export_category("Accuracy")
@export_range(0.0, 180.0) var spread_angle: float = 5.0

@export_category("Aiming")
@export_range(0.0, 1.0) var aim_move_speed_multiplier: float = 0.6 #the player would move at 60% its normal speed
@export_range(0.0, 1.0) var aim_spread_multiplier: float = 0.5 #the bullet spread is 50% smaller

@export_category("Visual")
@export var gun_scale: float = 1.0
@export var gun_visual_offset: Vector2 = Vector2.ZERO
@export var muzzle_position: Vector2 = Vector2(10.0, 0.0)
@export var muzzle_flash_scale: float = 1.0

@export var aim_cone_length: float = 200.0
@export var aim_cone_start_distance: float = 0.0
