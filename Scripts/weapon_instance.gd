class_name WeaponInstance
extends RefCounted


# ============================================
# WEAPON DATA
# ============================================

var weapon_data: WeaponData
var current_ammo: int = 0


# ============================================
# PERK BONUSES
# ============================================

var damage_multiplier: float = 1.0
var magazine_multiplier: float = 1.0
var fire_rate_multiplier: float = 1.0
var reload_multiplier: float = 1.0
var aim_multiplier: float = 1.0

var bullet_speed_bonus: float = 0.0
var bullets_per_shot_bonus: int = 0
var pierce_bonus: int = 0
var bounce_bonus: int = 0


# ============================================
# INIT
# ============================================

func _init(data: WeaponData) -> void:
	weapon_data = data
	current_ammo = get_magazine_size()


# ============================================
# RESET PERK BONUSES
# ============================================

func reset_perk_bonuses() -> void:
	damage_multiplier = 1.0
	magazine_multiplier = 1.0
	fire_rate_multiplier = 1.0
	reload_multiplier = 1.0
	aim_multiplier = 1.0

	bullet_speed_bonus = 0.0
	bullets_per_shot_bonus = 0
	pierce_bonus = 0
	bounce_bonus = 0


# ============================================
# FINAL STATS
# ============================================

func get_damage() -> int:
	return maxi(1, roundi(float(weapon_data.damage) * damage_multiplier))


func get_bullet_speed() -> float:
	return maxf(1.0, weapon_data.bullet_speed + bullet_speed_bonus)


func get_fire_rate() -> float:
	return maxf(0.01, weapon_data.fire_rate * fire_rate_multiplier)


func get_magazine_size() -> int:
	return maxi(1, roundi(float(weapon_data.magazine_size) * magazine_multiplier))


func get_reload_time() -> float:
	return maxf(0.01, weapon_data.reload_time * reload_multiplier)


func get_spread() -> float:
	return maxf(0.0, weapon_data.spread_angle)


func get_aim_spread_multiplier() -> float:
	return maxf(0.0, weapon_data.aim_spread_multiplier * aim_multiplier)


func get_bullets_per_shot() -> int:
	return maxi(1, weapon_data.bullets_per_shot + bullets_per_shot_bonus)


func get_pierce() -> int:
	return maxi(0, weapon_data.pierce + pierce_bonus)


func get_bounces() -> int:
	return maxi(0, weapon_data.bounces + bounce_bonus)
