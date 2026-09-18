extends Node

# Drag and drop your Wave1.tres, Wave2.tres files here in the Inspector
@export var waves: Array[Resource]

# Drag your EnemySpawner node into this slot in the Inspector
@export var enemy_spawner: Node2D 

var current_wave_index: int = 0
var enemies_remaining: int = 0

func _ready() -> void:
	# Add this node to a group so enemies can easily find it when they die
	add_to_group("wave_manager")
	
	# Start the first wave (index 0)
	start_wave(0)

func start_wave(index: int) -> void:
	if index >= waves.size():
		print("All waves completed! You win!")
		return
		
	current_wave_index = index
	var current_wave_data = waves[current_wave_index]
	
	# Get the target number of enemies to track for this wave
	enemies_remaining = current_wave_data.SpawnMaxEne
	
	# Tell the spawner to begin spawning using this wave's data
	if enemy_spawner:
		enemy_spawner.start_spawning_wave(current_wave_data)
	else:
		print("ERROR: Enemy Spawner not assigned in Wave Manager!")
	
	print("Wave ", index + 1, " started! Enemies to defeat: ", enemies_remaining)

func on_enemy_died() -> void:
	enemies_remaining -= 1
	
	if enemies_remaining <= 0:
		print("Wave cleared!")
		# Start the next wave
		start_wave(current_wave_index + 1)
