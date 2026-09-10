extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var speed := 400.0
@export var damage := 50

var direction := Vector2.RIGHT

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(func(): queue_free())
	sprite.play("default")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
