extends Node2D

const ENEMY_SCENE = preload("res://Scenes/enemy.tscn")

@onready var spawn_timer: Timer = $SpawnTimer

var spawn_interval: float
var max_enemies: int
var spawn_distance: float


func _ready() -> void:
	# Load values from the global GameSettings script
	spawn_interval = GameSettings.ENEMY_SPAWN_INTERVAL
	max_enemies = GameSettings.MAX_ENEMIES
	spawn_distance = GameSettings.ENEMY_SPAWN_DISTANCE

	# Set up spawn timer
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	# Do not spawn more enemies if we reached the maximum
	if get_tree().get_nodes_in_group("enemies").size() >= max_enemies:
		return

	spawn_enemy()


func spawn_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()

	# Add enemy to the current game scene
	get_tree().current_scene.add_child(enemy)

	# Give enemy a random position outside the screen
	enemy.global_position = get_random_spawn_position()


func get_random_spawn_position() -> Vector2:
	var screen_size = get_viewport_rect().size

	# Pick a random side:
	# 0 = Top
	# 1 = Right
	# 2 = Bottom
	# 3 = Left
	var side = randi_range(0, 3)

	var spawn_position = Vector2.ZERO

	match side:
		0: # Top
			spawn_position.x = randf_range(0.0, screen_size.x)
			spawn_position.y = -spawn_distance

		1: # Right
			spawn_position.x = screen_size.x + spawn_distance
			spawn_position.y = randf_range(0.0, screen_size.y)

		2: # Bottom
			spawn_position.x = randf_range(0.0, screen_size.x)
			spawn_position.y = screen_size.y + spawn_distance

		3: # Left
			spawn_position.x = -spawn_distance
			spawn_position.y = randf_range(0.0, screen_size.y)

	return spawn_position
