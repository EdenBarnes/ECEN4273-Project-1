extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var speed: float = 400.0
var damage: int = 50

var direction := Vector2.RIGHT


func _ready() -> void:
	# Load global bullet settings
	speed = GameSettings.BULLET_SPEED
	damage = GameSettings.BULLET_DAMAGE

	# Apply bullet size
	scale = Vector2.ONE * GameSettings.BULLET_SIZE

	body_entered.connect(_on_body_entered)

	$VisibleOnScreenNotifier2D.screen_exited.connect(
		func(): queue_free()
	)

	sprite.play("default")


func _process(delta: float) -> void:
	position += direction * speed * delta


func _on_body_entered(body) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)

	queue_free()
