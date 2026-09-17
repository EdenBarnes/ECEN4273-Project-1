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
# MAP SIZE
# ============================================

var map_size: Vector2 = Vector2(
	1536.0,
	1024.0
)

# ============================================
# READY
# ============================================

func _ready() -> void:
	scale = Vector2.ONE * GameSettings.BULLET_SIZE
	body_entered.connect(_on_body_entered)
	sprite.play("default")

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

# ============================================
# BULLET COLLISION
# ============================================

func _on_body_entered(body) -> void:

	# Ignore the physical map boundary.
	# Bullet bouncing is handled above.
	if body.is_in_group("boundary"):
		return

	# ============================================
	# DAMAGE
	# ============================================

	if body.has_method("take_damage"):
		body.take_damage(damage)

		# ========================================
		# PIERCING
		# ========================================

		if pierce > 0:
			pierce -= 1
		else:
			queue_free()
		return
