extends Node2D


# ============================================
# ENEMY SCENES
# ============================================

const ENEMY_SCENE = preload("res://Scenes/enemy.tscn")
const SPRINTER_SCENE = preload("res://Scenes/Sprinter.tscn")
const BIG_SCENE = preload("res://Scenes/BigGuy.tscn")


# ============================================
# NODES
# ============================================

@onready var spawn_timer: Timer = $SpawnTimer

# ============================================
# MAP SETTINGS
# ============================================

@export_category("Map Settings")

@export var map_size: Vector2 = Vector2(
	1536.0,
	1024.0
)

# How far inside the map edge enemies spawn.
# This keeps them from spawning inside the wall.
@export var edge_padding: float = 10.0

# ============================================
# SPAWNER SETTINGS
# ============================================

var spawn_interval: float
var max_enemies: int

# ============================================
# READY
# ============================================

func _ready() -> void:
	# Load values from GameSettings.
	spawn_interval = GameSettings.ENEMY_SPAWN_INTERVAL
	max_enemies = GameSettings.MAX_ENEMIES
	# Set up spawn timer.
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(
		_on_spawn_timer_timeout
	)
	spawn_timer.start()

# ============================================
# SPAWN TIMER
# ============================================

func _on_spawn_timer_timeout() -> void:
	# Don't exceed maximum enemy count.
	if (
		get_tree().get_nodes_in_group("enemies").size()
		>= max_enemies
	):
		return

	spawn_enemy()

# ============================================
# SPAWN ENEMY
# ============================================

func spawn_enemy() -> void:
	# Roll 1-10 to determine zombie type.
	var zomb: int = randi_range(1, 10)
	# Get random position along one of the
	# four edges of the entire map.
	var spawn_position: Vector2 = (
		get_random_spawn_position()
	)

	# ============================================
	# NORMAL ZOMBIE - 50%
	# ============================================

	if zomb <= 5:
		var enemy = ENEMY_SCENE.instantiate()
		get_tree().current_scene.add_child(enemy)
		enemy.global_position = spawn_position

	# ============================================
	# SPRINTER - 30%
	# ============================================

	elif zomb <= 8:
		var sprinter = SPRINTER_SCENE.instantiate()
		get_tree().current_scene.add_child(sprinter)
		sprinter.global_position = spawn_position

	# ============================================
	# BIG GUY - 20%
	# ============================================

	else:
		var big_guy = BIG_SCENE.instantiate()
		get_tree().current_scene.add_child(big_guy)
		big_guy.global_position = spawn_position

# ============================================
# RANDOM MAP EDGE POSITION
# ============================================

func get_random_spawn_position() -> Vector2:

	# Pick one of the four map edges.
	#
	# 0 = Top
	# 1 = Right
	# 2 = Bottom
	# 3 = Left

	var side: int = randi_range(0, 3)
	var spawn_position: Vector2 = Vector2.ZERO

	match side:
	
		# ========================================
		# TOP
		# ========================================

		0:
			spawn_position.x = randf_range(
				edge_padding,
				map_size.x - edge_padding
			)

			spawn_position.y = edge_padding

		# ========================================
		# RIGHT
		# ========================================

		1:
			spawn_position.x = (
				map_size.x - edge_padding
			)

			spawn_position.y = randf_range(
				edge_padding,
				map_size.y - edge_padding
			)

		# ========================================
		# BOTTOM
		# ========================================

		2:
			spawn_position.x = randf_range(
				edge_padding,
				map_size.x - edge_padding
			)

			spawn_position.y = (
				map_size.y - edge_padding
			)

		# ========================================
		# LEFT
		# ========================================

		3:
			spawn_position.x = edge_padding

			spawn_position.y = randf_range(
				edge_padding,
				map_size.y - edge_padding
			)

	return spawn_position
