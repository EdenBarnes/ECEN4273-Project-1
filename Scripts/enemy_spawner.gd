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

@onready var enemies_container: Node2D = $"../YSortWorld/Enemies"
@onready var spawn_timer: Timer = $SpawnTimer
@onready var water: CollisionPolygon2D = $"../GameBoundary/Water"

# ============================================
# MAP SETTINGS
# ============================================

@export_category("Map Settings")

@export var map_size: Vector2 = Vector2(
	1536.0,
	1024.0
)

# How far inside the map edge enemies spawn.
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

	# Get random position along one of
	# the four edges of the map.
	var spawn_position: Vector2 = (
		get_random_spawn_position()
	)


	# ============================================
	# NORMAL ZOMBIE - 50%
	# ============================================

	if zomb <= 5:

		var enemy = ENEMY_SCENE.instantiate()

		enemies_container.add_child(enemy)

		enemy.global_position = spawn_position


	# ============================================
	# SPRINTER - 30%
	# ============================================

	elif zomb <= 8:

		var sprinter = SPRINTER_SCENE.instantiate()

		enemies_container.add_child(sprinter)

		sprinter.global_position = spawn_position


	# ============================================
	# BIG GUY - 20%
	# ============================================

	else:

		var big_guy = BIG_SCENE.instantiate()

		enemies_container.add_child(big_guy)

		big_guy.global_position = spawn_position


# ============================================
# RANDOM MAP EDGE POSITION
# ============================================

# ============================================
# GET VALID RANDOM SPAWN POSITION
# ============================================

func get_random_spawn_position() -> Vector2:

	# Try up to 50 times to find a spawn
	# position that is not inside the water.
	for attempt in range(50):

		var spawn_position: Vector2 = (
			get_random_edge_position()
		)

		# If this position is not in the water,
		# use it.
		if not is_position_in_water(
			spawn_position
		):
			return spawn_position

	# If no valid position was found after
	# 50 attempts, use the center of the map.
	print(
		"WARNING: Could not find valid enemy spawn position."
	)

	return Vector2(
		map_size.x / 2.0,
		map_size.y / 2.0
	)


# ============================================
# RANDOM MAP EDGE POSITION
# ============================================

func get_random_edge_position() -> Vector2:

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


# ============================================
# CHECK IF POSITION IS IN WATER
# ============================================

func is_position_in_water(
	spawn_position: Vector2
) -> bool:

	var local_position: Vector2 = (
		water.to_local(spawn_position)
	)

	return Geometry2D.is_point_in_polygon(
		local_position,
		water.polygon
	)
