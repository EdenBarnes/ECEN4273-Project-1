extends Area2D


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# ============================================
# BULLET SETTINGS
# ============================================

var speed: float = 400.0
var damage: int = 50
var pierce: int = 0
var bounces: int = 0

var direction := Vector2.RIGHT
var lifetime: float = 10.0

# ============================================
# HIT TRACKING
# ============================================

var hit_targets: Array[Node] = []


# ============================================
# MAP SIZE
# ============================================

var map_size: Vector2 = Vector2(
	1536.0,
	1024.0
)

# ============================================
# DAMAGE NUMBER
# ============================================

const DAMAGE_NUMBER_SCENE = preload("res://Scenes/DamageNumber.tscn")


# ============================================
# READY
# ============================================

func _ready() -> void:
	scale = Vector2.ONE * GameSettings.BULLET_SIZE

	# Detect CharacterBody2D / StaticBody2D.
	body_entered.connect(_on_body_entered)

	# Detect enemy AttackHitbox Area2D.
	area_entered.connect(_on_area_entered)

	sprite.play("default")


# ============================================
# SHOW DAMAGE NUMBER
# ============================================

func show_damage_number(amount: int) -> void:
	var damage_number: Node2D = DAMAGE_NUMBER_SCENE.instantiate()

	get_tree().current_scene.add_child(damage_number)

	damage_number.global_position = global_position
	damage_number.set_damage(amount)
	damage_number.set_hit_direction(direction)


# ============================================
# BULLET MOVEMENT
# ============================================

func _process(delta: float) -> void:
	global_position += direction * speed * delta

	check_map_boundary()

	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()


# ============================================
# MAP BOUNDARY
# ============================================

func check_map_boundary() -> void:
	var hit_boundary: bool = false


	# ============================================
	# LEFT EDGE
	# ============================================

	if global_position.x <= 0.0:
		global_position.x = 0.0
		direction.x = abs(direction.x)
		hit_boundary = true


	# ============================================
	# RIGHT EDGE
	# ============================================

	elif global_position.x >= map_size.x:
		global_position.x = map_size.x
		direction.x = -abs(direction.x)
		hit_boundary = true


	# ============================================
	# TOP EDGE
	# ============================================

	if global_position.y <= 0.0:
		global_position.y = 0.0
		direction.y = abs(direction.y)
		hit_boundary = true


	# ============================================
	# BOTTOM EDGE
	# ============================================

	elif global_position.y >= map_size.y:
		global_position.y = map_size.y
		direction.y = -abs(direction.y)
		hit_boundary = true


	# ============================================
	# HANDLE BOUNCE
	# ============================================

	if hit_boundary:
		if bounces > 0:
			bounces -= 1
		else:
			queue_free()


func _on_body_entered(body: Node) -> void:

	# ============================================
	# MAP BOUNDARY
	# ============================================

	if body.is_in_group("boundary"):
		return


	# ============================================
	# BULLET OBSTACLE
	# ============================================

	if body.is_in_group("bullet_obstacle"):

		if bounces > 0:
			bounce_off_obstacle(body)
			bounces -= 1
		else:
			queue_free()

		return


	# ============================================
	# DAMAGE
	# ============================================

	if body.has_method("take_damage"):
		damage_target(body)


# ============================================
# AREA COLLISION
# ============================================

func _on_area_entered(area: Area2D) -> void:

	# The AttackHitbox belongs to the enemy.
	var enemy: Node = area.get_parent()

	# Make sure this Area2D actually belongs
	# to an enemy.
	if not enemy.is_in_group("enemies"):
		return

	if enemy.has_method("take_damage"):
		damage_target(enemy)


# ============================================
# DAMAGE TARGET
# ============================================

func damage_target(target: Node) -> void:
	# Prevent hitting the same enemy twice
	if target in hit_targets:
		return

	hit_targets.append(target)

	# Damage enemy
	target.take_damage(damage)

	# Show damage number
	show_damage_number(damage)

	# ============================================
	# PIERCING
	# ============================================

	if pierce > 0:
		pierce -= 1
	else:
		queue_free()

# ============================================
# BOUNCE OFF OBSTACLE
# ============================================

func bounce_off_obstacle(body: Node) -> void:

	var collision_polygon: CollisionPolygon2D = (
		body.get_node_or_null("CollisionShape2D")
	)

	if collision_polygon == null:
		direction *= -1.0
		return

	var polygon: PackedVector2Array = (
		collision_polygon.polygon
	)

	if polygon.size() < 2:
		direction *= -1.0
		return


	# ============================================
	# FIND CLOSEST POLYGON EDGE
	# ============================================

	var bullet_local: Vector2 = (
		collision_polygon.to_local(
			global_position
		)
	)

	var closest_distance: float = INF
	var closest_edge: Vector2 = Vector2.ZERO


	for i: int in range(polygon.size()):

		var point_a: Vector2 = polygon[i]

		var point_b: Vector2 = polygon[
			(i + 1) % polygon.size()
		]

		var closest_point: Vector2 = (
			Geometry2D.get_closest_point_to_segment(
				bullet_local,
				point_a,
				point_b
			)
		)

		var distance: float = (
			bullet_local.distance_to(
				closest_point
			)
		)

		if distance < closest_distance:
			closest_distance = distance
			closest_edge = point_b - point_a


	# ============================================
	# GET SURFACE NORMAL
	# ============================================

	var normal: Vector2 = Vector2(
		-closest_edge.y,
		closest_edge.x
	).normalized()


	# Make sure the normal points against
	# the incoming bullet.
	if direction.dot(normal) > 0.0:
		normal = -normal


	# ============================================
	# REFLECT BULLET
	# ============================================

	direction = direction.bounce(
		normal
	).normalized()


	# ============================================
	# PUSH BULLET AWAY
	# ============================================

	global_position += (
		direction * 6.0
	)
