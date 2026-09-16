extends StaticBody2D

@onready var top: CollisionShape2D = $Top
@onready var bottom: CollisionShape2D = $Bottom
@onready var left: CollisionShape2D = $Left
@onready var right: CollisionShape2D = $Right

@export var wall_thickness: float = 20.0


func _ready() -> void:
	call_deferred("setup_boundaries")

	get_viewport().size_changed.connect(
		func():
			call_deferred("setup_boundaries")
	)


func setup_boundaries() -> void:
	var screen_size = get_viewport_rect().size

	# TOP
	top.position = Vector2(
		screen_size.x / 2.0,
		-wall_thickness / 2.0
	)

	top.shape.size = Vector2(
		screen_size.x + wall_thickness * 2.0,
		wall_thickness
	)

	# BOTTOM
	bottom.position = Vector2(
		screen_size.x / 2.0,
		screen_size.y + wall_thickness / 2.0
	)

	bottom.shape.size = Vector2(
		screen_size.x + wall_thickness * 2.0,
		wall_thickness
	)

	# LEFT
	left.position = Vector2(
		-wall_thickness / 2.0,
		screen_size.y / 2.0
	)

	left.shape.size = Vector2(
		wall_thickness,
		screen_size.y + wall_thickness * 2.0
	)

	# RIGHT
	right.position = Vector2(
		screen_size.x + wall_thickness / 2.0,
		screen_size.y / 2.0
	)

	right.shape.size = Vector2(
		wall_thickness,
		screen_size.y + wall_thickness * 2.0
	)
