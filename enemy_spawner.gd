extends Node2D

const ENEMY_SCENE = preload("res://enemy.tscn")

@onready var spawn_timer: Timer = $SpawnTimer

@export var spawn_interval := 2.0
@export var max_enemies := 10


func _ready() -> void:
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.start()
	
func _on_spawn_timer_timeout():
	if get_tree().get_nodes_in_group("enemies").size() >= max_enemies:
		return
	
	spawn_enemy()
	
func spawn_enemy():
	var enemy = ENEMY_SCENE.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = get_random_spawn_position()

func get_random_spawn_position() -> Vector2:
	# placeholder — see options below for smarter positioning
	return global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
