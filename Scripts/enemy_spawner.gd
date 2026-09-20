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
# WAVE SETTINGS
# ============================================

var wave_Data: Resource = null

# Used for normal waves only
var enemies_left_to_spawn: int = 0

# Determines if normal enemies should continuously
# refill while the boss is alive
var boss_wave_active: bool = false


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


# ============================================
# START SPAWNING WAVE
# ============================================

func start_spawning_wave(new_wave_data: Resource) -> void:
	wave_Data = new_wave_data

	enemies_left_to_spawn = wave_Data.SpawnMaxEne
	boss_wave_active = wave_Data.Bossspawn

	spawn_timer.wait_time = wave_Data.SpawnInterval
	spawn_timer.start()


# ============================================
# STOP SPAWNING
# ============================================

func stop_spawning() -> void:
	boss_wave_active = false
	spawn_timer.stop()


# ============================================
# SPAWN TIMER
# ============================================

func _on_spawn_timer_timeout() -> void:
	if wave_Data == null:
		return

	# ============================================
	# BOSS WAVE
	# ============================================

	if boss_wave_active:
		spawn_boss_wave_enemy()
		return

	# ============================================
	# NORMAL WAVE
	# ============================================

	spawn_normal_wave_enemy()


# ============================================
# NORMAL WAVE SPAWNING
# ============================================

func spawn_normal_wave_enemy() -> void:
	# Stop once every enemy for the wave
	# has been spawned
	if enemies_left_to_spawn <= 0:
		spawn_timer.stop()
		return

	# Do not exceed the living enemy cap
	if get_regular_enemy_count() >= GameSettings.MAX_ENEMIES:
		return

	spawn_enemy()

	enemies_left_to_spawn -= 1


# ============================================
# BOSS WAVE SPAWNING
# ============================================

func spawn_boss_wave_enemy() -> void:
	# During a boss wave there is NO total
	# spawn limit.
	#
	# SpawnMaxEne instead controls how many
	# regular enemies may be alive at once.

	var regular_enemy_count: int = get_regular_enemy_count()

	if regular_enemy_count >= wave_Data.SpawnMaxEne:
		return

	spawn_enemy()


# ============================================
# GET REGULAR ENEMY COUNT
# ============================================

func get_regular_enemy_count() -> int:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var regular_enemy_count: int = 0

	for enemy: Node in enemies:
		if enemy == null:
			continue

		# Do not count the boss
		if enemy.is_in_group("boss"):
			continue

		# Do not count zombies that are already dead
		if enemy.get("is_dead") == true:
			continue

		regular_enemy_count += 1

	return regular_enemy_count


# ============================================
# SPAWN ENEMY
# ============================================

func spawn_enemy() -> void:
	var zomb: int = randi_range(1, 100)
	var spawn_position: Vector2 = get_random_spawn_position()

	# ============================================
	# NORMAL ZOMBIE
	# ============================================

	if zomb <= wave_Data.normalper:
		var enemy = ENEMY_SCENE.instantiate()

		enemies_container.add_child(enemy)
		enemy.global_position = spawn_position

	# ============================================
	# SPRINTER
	# ============================================

	elif zomb <= wave_Data.normalper + wave_Data.Sprintper:
		var sprinter = SPRINTER_SCENE.instantiate()

		enemies_container.add_child(sprinter)
		sprinter.global_position = spawn_position

	# ============================================
	# BIG GUY
	# ============================================

	elif zomb <= wave_Data.normalper + wave_Data.Sprintper + wave_Data.bigper:
		var big_guy = BIG_SCENE.instantiate()

		enemies_container.add_child(big_guy)
		big_guy.global_position = spawn_position


# ============================================
# GET VALID RANDOM SPAWN POSITION
# ============================================

func get_random_spawn_position() -> Vector2:
	for _attempt in range(50):
		var spawn_position: Vector2 = get_random_edge_position()

		if not is_position_in_water(spawn_position):
			return spawn_position

	print("WARNING: Could not find valid enemy spawn position.")

	return Vector2(map_size.x / 2.0, map_size.y / 2.0)


# ============================================
# RANDOM MAP EDGE POSITION
# ============================================

func get_random_edge_position() -> Vector2:
	var side: int = randi_range(0, 3)
	var spawn_position: Vector2 = Vector2.ZERO

	match side:

		# ========================================
		# TOP
		# ========================================

		0:
			spawn_position.x = randf_range(edge_padding, map_size.x - edge_padding)
			spawn_position.y = edge_padding

		# ========================================
		# RIGHT
		# ========================================

		1:
			spawn_position.x = map_size.x - edge_padding
			spawn_position.y = randf_range(edge_padding, map_size.y - edge_padding)

		# ========================================
		# BOTTOM
		# ========================================

		2:
			spawn_position.x = randf_range(edge_padding, map_size.x - edge_padding)
			spawn_position.y = map_size.y - edge_padding

		# ========================================
		# LEFT
		# ========================================

		3:
			spawn_position.x = edge_padding
			spawn_position.y = randf_range(edge_padding, map_size.y - edge_padding)

	return spawn_position


# ============================================
# CHECK IF POSITION IS IN WATER
# ============================================

func is_position_in_water(spawn_position: Vector2) -> bool:
	var local_position: Vector2 = water.to_local(spawn_position)

	return Geometry2D.is_point_in_polygon(local_position, water.polygon)
