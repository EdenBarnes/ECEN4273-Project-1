extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var speed: float = 400.0
var damage: int = 50

var pierce: int = 0
var bounces: int = 0

var direction := Vector2.RIGHT

var lifetime: float = 10.0


func _ready() -> void:
	scale = Vector2.ONE * GameSettings.BULLET_SIZE

	body_entered.connect(_on_body_entered)

	sprite.play("default")


func _process(delta: float) -> void:
	# Move bullet
	global_position += direction * speed * delta

	# Check screen boundary
	check_boundary()

	# Bullet lifetime
	lifetime -= delta

	if lifetime <= 0.0:
		queue_free()


func check_boundary() -> void:
	var screen_size = get_viewport_rect().size

	var hit_boundary := false


	# ============================================
	# LEFT WALL
	# ============================================

	if global_position.x <= 0.0:
		global_position.x = 0.0

		direction.x = abs(direction.x)

		hit_boundary = true


	# ============================================
	# RIGHT WALL
	# ============================================

	elif global_position.x >= screen_size.x:
		global_position.x = screen_size.x

		direction.x = -abs(direction.x)

		hit_boundary = true


	# ============================================
	# TOP WALL
	# ============================================

	if global_position.y <= 0.0:
		global_position.y = 0.0

		direction.y = abs(direction.y)

		hit_boundary = true


	# ============================================
	# BOTTOM WALL
	# ============================================

	elif global_position.y >= screen_size.y:
		global_position.y = screen_size.y

		direction.y = -abs(direction.y)

		hit_boundary = true


	# ============================================
	# HANDLE BOUNCE COUNT
	# ============================================

	if hit_boundary:
		if bounces > 0:
			bounces -= 1
		else:
			queue_free()


func _on_body_entered(body) -> void:

	# Ignore the game boundary.
	# Bullet bouncing is handled by check_boundary().
	if body.is_in_group("boundary"):
		return


	# ============================================
	# HIT ENEMY
	# ============================================

	if body.has_method("take_damage"):
		body.take_damage(damage)

		if pierce > 0:
			pierce -= 1
		else:
			queue_free()

		return
