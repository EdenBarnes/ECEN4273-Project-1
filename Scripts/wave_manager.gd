extends Node


# ============================================
# BOSS SCENE
# ============================================

const BOSS_SCENE = preload("res://Scenes/Boss.tscn")


# ============================================
# WAVE SETTINGS
# ============================================

# Drag Wave1.tres, Wave2.tres, etc. here
@export var waves: Array[Resource]

# Drag the EnemySpawner node here
@export var enemy_spawner: Node2D


# ============================================
# NODES
# ============================================

@onready var enemies_container: Node2D = $"../YSortWorld/Enemies"


# ============================================
# WAVE VARIABLES
# ============================================

var current_wave_index: int = 0
var current_wave_data: Waves2 = null

var enemies_remaining: int = 0

var boss_alive: bool = false
var boss_wave: bool = false
var wave_active: bool = false
var wave_waiting: bool = false


# ============================================
# READY
# ============================================

func _ready() -> void:
	add_to_group("wave_manager")

	# Prepare Wave 1
	start_wave(0)


# ============================================
# START WAVE
# ============================================

func start_wave(index: int) -> void:
	# Check if all waves are complete
	if index >= waves.size():
		print("All waves completed! You win!")
		wave_active = false
		wave_waiting = false
		return

	# Get incoming wave
	current_wave_index = index
	current_wave_data = waves[current_wave_index] as Waves2

	if current_wave_data == null:
		print("ERROR: Invalid wave resource!")
		return

	# ============================================
	# WAIT BEFORE INCOMING WAVE
	# ============================================

	wave_active = false
	wave_waiting = true

	var start_delay: float = current_wave_data.StartDelay

	print("Wave ", current_wave_index + 1, " starts in ", start_delay, " seconds!")

	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout

	wave_waiting = false

	# ============================================
	# APPLY WAVE SETTINGS
	# ============================================

	GameSettings.apply_wave(current_wave_data)

	# ============================================
	# ENEMY COUNT
	# ============================================

	enemies_remaining = current_wave_data.SpawnMaxEne

	# ============================================
	# CHECK FOR BOSS WAVE
	# ============================================

	boss_wave = current_wave_data.Bossspawn
	boss_alive = false
	wave_active = true

	print("Wave ", current_wave_index + 1, " started!")

	# ============================================
	# BOSS WAVE
	# ============================================

	if boss_wave:
		print("BOSS WAVE!")
		spawn_boss()
		return

	# ============================================
	# NORMAL WAVE
	# ============================================

	start_normal_spawning()


# ============================================
# START NORMAL ENEMY SPAWNING
# ============================================

func start_normal_spawning() -> void:
	if enemy_spawner == null:
		print("ERROR: Enemy Spawner not assigned!")
		return

	enemy_spawner.start_spawning_wave(current_wave_data)

	print("Enemies to defeat: ", enemies_remaining)


# ============================================
# SPAWN BOSS
# ============================================

func spawn_boss() -> void:
	if enemy_spawner == null:
		print("ERROR: Enemy Spawner not assigned!")
		return

	# Create boss
	var boss: CharacterBody2D = BOSS_SCENE.instantiate()

	# Add boss to enemies container
	enemies_container.add_child(boss)

	# Set boss position
	boss.global_position = enemy_spawner.get_random_spawn_position()

	# Boss is alive
	boss_alive = true

	print("Boss spawned!")

	# Start regular enemies
	start_normal_spawning()


# ============================================
# NORMAL ENEMY DIED
# ============================================

func on_enemy_died() -> void:
	if not wave_active:
		return

	# Lower enemy count
	enemies_remaining -= 1

	if enemies_remaining < 0:
		enemies_remaining = 0

	print("Enemies remaining: ", enemies_remaining)

	# Boss wave
	if boss_wave:
		check_boss_wave_complete()
		return

	# Normal wave
	if enemies_remaining <= 0:
		complete_wave()


# ============================================
# BOSS DIED
# ============================================

func on_boss_died() -> void:
	if not wave_active:
		return

	if not boss_wave:
		return

	if not boss_alive:
		return

	# Boss is dead
	boss_alive = false

	print("Boss defeated!")

	# Stop new enemies
	if enemy_spawner != null and enemy_spawner.has_method("stop_spawning"):
		enemy_spawner.stop_spawning()

	# Check wave
	check_boss_wave_complete()


# ============================================
# CHECK BOSS WAVE COMPLETE
# ============================================

func check_boss_wave_complete() -> void:
	# Boss must be dead
	if boss_alive:
		return

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var living_enemies: int = 0

	for enemy: Node in enemies:
		if enemy == null:
			continue

		# Ignore boss
		if enemy.is_in_group("boss"):
			continue

		# Ignore enemies already dying
		if enemy.get("is_dead") == true:
			continue

		living_enemies += 1

	# Finish boss wave when all regular enemies are gone
	if living_enemies <= 0:
		complete_wave()


# ============================================
# COMPLETE WAVE
# ============================================

func complete_wave() -> void:
	if not wave_active:
		return

	wave_active = false

	print("Wave ", current_wave_index + 1, " cleared!")

	# Stop spawner
	if enemy_spawner != null and enemy_spawner.has_method("stop_spawning"):
		enemy_spawner.stop_spawning()

	# Prepare incoming wave
	start_wave(current_wave_index + 1)
