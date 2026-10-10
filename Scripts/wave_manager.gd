extends Node

# ============================================
# BOSS SCENE
# ============================================

const BOSS_SCENE = preload("res://Scenes/Boss.tscn")

# ============================================
# WAVE SETTINGS
# ============================================

@export var waves: Array[Resource]
@export var enemy_spawner: Node2D

# ============================================
# DEBUG
# ============================================
# Set this to 1 in the Inspector to play only
# the first wave, so the win screen can be
# tested without clearing all ten.
# Leave it at 0 to use every wave in the list.
# ============================================

@export var debug_wave_limit: int = 0


# ============================================
# WIN TIMING
# ============================================

# Beat after the last enemy dies, before fading
const WIN_DELAY: float = 1.0

# How long the fade to the win screen takes
const WIN_FADE_DURATION: float = 2.0


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
# COUNTDOWN VARIABLES
# ============================================

var countdown_paused: bool = false
var countdown_remaining: float = 0.0
#siren sound for before the wave starts
@onready var siren_noise: AudioStreamPlayer = $"../Siren Noise"

# Seconds left on the countdown when the siren fires
const SIREN_LEAD_TIME: float = 3.0

# Stops the siren retriggering every frame
var siren_played: bool = false

# ============================================
# SIGNALS
# ============================================

signal wave_countdown_started(wave_number: int, duration: float)
signal wave_started(wave_number: int)
signal enemy_count_changed(enemies_remaining: int)

signal boss_started(boss: Node)
signal boss_defeated

signal all_waves_completed

# ============================================
# READY
# ============================================

func _ready() -> void:
	add_to_group("wave_manager")

	# ============================================
	# DEBUG WAVE LIMIT
	# ============================================

	if debug_wave_limit > 0 and debug_wave_limit < waves.size():
		waves = waves.slice(0, debug_wave_limit)
		print("DEBUG: only playing ", waves.size(), " wave(s)")

	call_deferred("start_wave", 0)

# ============================================
# START GAME
# ============================================

func start_game() -> void:
	if wave_active or wave_waiting:
		return

	start_wave(0)

# ============================================
# PROCESS COUNTDOWN
# ============================================

func _process(delta: float) -> void:
	if not wave_waiting:
		return

	if countdown_paused:
		return

	if countdown_remaining <= 0.0:
		return

	countdown_remaining -= delta

	# ============================================
	# SIREN
	# ============================================

	if not siren_played and countdown_remaining <= SIREN_LEAD_TIME:
		siren_played = true

		if siren_noise != null:
			siren_noise.play()

	if countdown_remaining <= 0.0:
		countdown_remaining = 0.0
		finish_wave_countdown()

# ============================================
# START WAVE COUNTDOWN
# ============================================

func start_wave(index: int) -> void:

	# ============================================
	# ALL WAVES COMPLETE
	# ============================================

	if index >= waves.size():
		print("All waves completed! You win!")

		wave_active = false
		wave_waiting = false
		countdown_paused = false
		countdown_remaining = 0.0

		all_waves_completed.emit()

		go_to_win_screen()
		return

	# ============================================
	# GET INCOMING WAVE
	# ============================================

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
	countdown_paused = false

	var wave_number: int = current_wave_index + 1
	var start_delay: float = current_wave_data.StartDelay

	countdown_remaining = start_delay

	print("Wave ", wave_number, " starts in ", start_delay, " seconds!")

	wave_countdown_started.emit(wave_number, start_delay)

	# Re-arm the siren for this countdown
	siren_played = false

	if countdown_remaining <= 0.0:
		finish_wave_countdown()

# ============================================
# FINISH WAVE COUNTDOWN
# ============================================

func finish_wave_countdown() -> void:
	if not wave_waiting:
		return

	wave_waiting = false
	countdown_paused = false
	countdown_remaining = 0.0

	begin_wave()

# ============================================
# PAUSE WAVE COUNTDOWN
# ============================================

func pause_wave_countdown() -> void:
	if not wave_waiting:
		return

	countdown_paused = true

	print("Wave countdown paused at ", snappedf(countdown_remaining, 0.1), " seconds.")

# ============================================
# RESUME WAVE COUNTDOWN
# ============================================

func resume_wave_countdown() -> void:
	if not wave_waiting:
		return

	countdown_paused = false

	print("Wave countdown resumed at ", snappedf(countdown_remaining, 0.1), " seconds.")

# ============================================
# BETWEEN WAVES CHECK
# ============================================

func is_between_waves() -> bool:
	return wave_waiting and not wave_active

# ============================================
# GET COUNTDOWN TIME
# ============================================

func get_countdown_remaining() -> float:
	return countdown_remaining

# ============================================
# BEGIN WAVE
# ============================================

func begin_wave() -> void:
	if current_wave_data == null:
		print("ERROR: No current wave data!")
		return

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

	var wave_number: int = current_wave_index + 1

	print("Wave ", wave_number, " started!")

	wave_started.emit(wave_number)

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

	enemy_count_changed.emit(enemies_remaining)
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

	# ============================================
	# CREATE BOSS
	# ============================================

	var boss: CharacterBody2D = BOSS_SCENE.instantiate()

	enemies_container.add_child(boss)

	# ============================================
	# SET BOSS POSITION
	# ============================================

	boss.global_position = enemy_spawner.get_random_spawn_position()

	# ============================================
	# BOSS IS ALIVE
	# ============================================

	boss_alive = true

	print("Boss spawned!")

	# Tell HUD which boss to track
	boss_started.emit(boss)

	# ============================================
	# START REGULAR ENEMIES
	# ============================================

	start_normal_spawning()

# ============================================
# NORMAL ENEMY DIED
# ============================================

func on_enemy_died() -> void:
	if not wave_active:
		return

	# ============================================
	# NORMAL WAVE
	# ============================================

	if not boss_wave:
		enemies_remaining -= 1
		enemies_remaining = maxi(enemies_remaining, 0)

		print("Enemies remaining: ", enemies_remaining)

		enemy_count_changed.emit(enemies_remaining)

		if enemies_remaining <= 0:
			complete_wave()

		return

	# ============================================
	# BOSS WAVE
	# ============================================

	if boss_alive:
		return

	check_boss_wave_complete()

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

	# ============================================
	# BOSS IS DEAD
	# ============================================

	boss_alive = false

	print("Boss defeated!")

	boss_defeated.emit()

	# ============================================
	# STOP NEW ENEMIES
	# ============================================

	if enemy_spawner != null and enemy_spawner.has_method("stop_spawning"):
		enemy_spawner.stop_spawning()

	# ============================================
	# CHECK REMAINING ENEMIES
	# ============================================

	check_boss_wave_complete()

# ============================================
# CHECK BOSS WAVE COMPLETE
# ============================================

func check_boss_wave_complete() -> void:
	if boss_alive:
		return

	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var living_enemies: int = 0

	for enemy: Node in enemies:
		if enemy == null:
			continue

		if enemy.is_in_group("boss"):
			continue

		if enemy.get("is_dead") == true:
			continue

		living_enemies += 1

	# ============================================
	# UPDATE HUD COUNT
	# ============================================

	enemies_remaining = living_enemies
	enemy_count_changed.emit(enemies_remaining)

	print("Enemies remaining after boss: ", enemies_remaining)

	# ============================================
	# FINISH BOSS WAVE
	# ============================================

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

	# ============================================
	# STOP SPAWNER
	# ============================================

	if enemy_spawner != null and enemy_spawner.has_method("stop_spawning"):
		enemy_spawner.stop_spawning()

	# ============================================
	# COLLECT REMAINING COINS
	# ============================================

	call_deferred("collect_remaining_coins")

	# ============================================
	# PREPARE NEXT WAVE
	# ============================================

	start_wave(current_wave_index + 1)

# ============================================
# WIN SCREEN
# ============================================

func go_to_win_screen() -> void:

	# ============================================
	# STOP THE GAME
	# ============================================

	if enemy_spawner != null and enemy_spawner.has_method("stop_spawning"):
		enemy_spawner.stop_spawning()

	# Freeze the player so they cannot be killed
	# during the fade and trigger the death screen
	# at the same time.
	var player: Node = get_tree().get_first_node_in_group("player")

	if player != null:
		player.set("is_locked", true)

	# ============================================
	# FADE OUT AND SWITCH
	# ============================================

	await get_tree().create_timer(WIN_DELAY).timeout

	await ScreenFade.to_black(self, WIN_FADE_DURATION)

	get_tree().change_scene_to_file("res://Scenes/win_screen.tscn")

# ============================================
# COLLECT REMAINING COINS
# ============================================

func collect_remaining_coins() -> void:
	await get_tree().process_frame

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		return

	var coins: Array[Node] = get_tree().get_nodes_in_group("coins")

	for coin: Node in coins:
		if coin.has_method("move_to_player"):
			coin.move_to_player(player)
