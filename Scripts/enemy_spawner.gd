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

# Leave this empty! The WaveManager will fill it in.
var wave_Data: Resource 

# Use a local variable to count spawns so you don't corrupt your .tres file
var enemies_left_to_spawn: int = 0 

# ============================================
# MAP SETTINGS
# ============================================
@export_category("Map Settings")
@export var map_size: Vector2 = Vector2(1536.0, 1024.0)
@export var edge_padding: float = 10.0

# ============================================
# READY
# ============================================
func _ready() -> void:
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	# Notice we DO NOT start the timer here anymore. 
	# The WaveManager will tell it when to start.

# ============================================
# NEW FUNCTION: CALLED BY WAVE MANAGER
# ============================================
func start_spawning_wave(new_wave_data: Resource) -> void:
	wave_Data = new_wave_data
	
	# Read the data from your .tres file (using the exact inspector name)
	enemies_left_to_spawn = wave_Data.SpawnMaxEne
	
	# Update the timer to use the wave's specific spawn interval
	spawn_timer.wait_time = wave_Data.SpawnInterval
	
	spawn_timer.start()

# ============================================
# SPAWN TIMER
# ============================================
func _on_spawn_timer_timeout() -> void:
	# Stop spawning if we've spawned all enemies for this wave
	if enemies_left_to_spawn <= 0:
		spawn_timer.stop()
		return

	# Check against the global max enemy cap (from GameSettings)
	if get_tree().get_nodes_in_group("enemies").size() >= GameSettings.MAX_ENEMIES:
		return

	# Spawn the enemy and reduce our local counter
	spawn_enemy()
	enemies_left_to_spawn -= 1
# ============================================
# SPAWN ENEMY
# ============================================

func spawn_enemy() -> void:

	# Roll 1-10 to determine zombie type.
		var zomb: int = randi_range(1, 100)

	# Get random position along one of
	# the four edges of the map.
		var spawn_position: Vector2 = (get_random_spawn_position())


	# ============================================
	# NORMAL ZOMBIE - 50%
	# ============================================

		if zomb <= wave_Data.normalper:

			var enemy = ENEMY_SCENE.instantiate()

			enemies_container.add_child(enemy)

			enemy.global_position = spawn_position


	# ============================================
	# SPRINTER - 30%
	# ============================================

		elif zomb <= wave_Data.Sprintper + wave_Data.normalper:

			var sprinter = SPRINTER_SCENE.instantiate()

			enemies_container.add_child(sprinter)

			sprinter.global_position = spawn_position


	# ============================================
	# BIG GUY - 20%
	# ============================================

		elif zomb <= wave_Data.Sprintper + wave_Data.normalper + wave_Data.bigper:

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
