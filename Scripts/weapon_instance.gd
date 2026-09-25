class_name WeaponInstance
extends RefCounted


# The original weapon definition
var weapon_data: WeaponData


# Current ammo
var current_ammo: int = 0


# ============================================
# STAT BUFFS
# ============================================

var damage_bonus: int = 0
var bullet_speed_bonus: float = 0.0
var fire_rate_bonus: float = 0.0
var magazine_size_bonus: int = 0
var spread_bonus: float = 0.0
var pierce_bonus: int = 0
var bounce_bonus: int = 0


func _init(data: WeaponData) -> void:
	weapon_data = data
	current_ammo = get_magazine_size()


# ============================================
# FINAL STATS
# ============================================

func get_damage() -> int:
	return weapon_data.damage + damage_bonus


func get_bullet_speed() -> float:
	return weapon_data.bullet_speed + bullet_speed_bonus


func get_fire_rate() -> float:
	return max(0.01, weapon_data.fire_rate + fire_rate_bonus)


func get_magazine_size() -> int:
	return max(1, weapon_data.magazine_size + magazine_size_bonus)


func get_spread() -> float:
	return max(0.0, weapon_data.spread_angle + spread_bonus)


func get_pierce() -> int:
	return max(0, weapon_data.pierce + pierce_bonus)


func get_bounces() -> int:
	return max(0, weapon_data.bounces + bounce_bonus)
