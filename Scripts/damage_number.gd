extends Node2D


# ============================================
# SETTINGS
# ============================================

@export var lifetime: float = 0.65
@export var horizontal_speed_min: float = 10.0
@export var horizontal_speed_max: float = 30.0
@export var upward_speed_min: float = 35.0
@export var upward_speed_max: float = 55.0
@export var gravity: float = 35.0


# ============================================
# SIZE SETTINGS
# ============================================

@export var base_damage: float = 25.0
@export var base_scale: float = 1.0
@export var scale_strength: float = 0.25
@export var min_scale: float = 0.7
@export var max_scale: float = 2.0


# ============================================
# NODES
# ============================================

@onready var damage_label: Label = $Label


# ============================================
# VARIABLES
# ============================================

var velocity: Vector2 = Vector2.ZERO
var time_alive: float = 0.0


# ============================================
# PROCESS
# ============================================

func _process(delta: float) -> void:
	time_alive += delta

	position += velocity * delta
	velocity.y += gravity * delta

	var fade_percent: float = time_alive / lifetime
	modulate.a = 1.0 - clampf(fade_percent, 0.0, 1.0)

	if time_alive >= lifetime:
		queue_free()


# ============================================
# SET DAMAGE
# ============================================

func set_damage(amount: int) -> void:
	damage_label.text = str(amount)

	var damage_ratio: float = float(amount) / base_damage
	var damage_scale: float = base_scale + log(maxf(damage_ratio, 0.1)) * scale_strength

	damage_scale = clampf(damage_scale, min_scale, max_scale)

	scale = Vector2.ONE * damage_scale


# ============================================
# HIT DIRECTION
# ============================================

func set_hit_direction(new_direction: Vector2) -> void:
	var random_x: float = randf_range(horizontal_speed_min, horizontal_speed_max)

	if new_direction.x < 0.0:
		random_x = -random_x
	elif new_direction.x == 0.0:
		if randf() < 0.5:
			random_x = -random_x

	var random_y: float = -randf_range(upward_speed_min, upward_speed_max)

	velocity = Vector2(random_x, random_y)
