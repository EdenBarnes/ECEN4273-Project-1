extends Node


# ============================================
# CURRENT WAVE
# ============================================

var wave_Data: Waves2 = load("res://Waves/Wave1.tres")

# ============================================
# PLAYER SETTINGS
# ============================================

var PLAYER_SPEED: float = 150.0
var PLAYER_SIZE: float = 1.0
var PLAYER_MAX_HEALTH: int = 100
var PLAYER_INVULNERABILITY_DURATION: float = 0.2
var PLAYER_HURT_DURATION: float = 0.1

# ============================================
# PLAYER DASH SETTINGS
# ============================================

var PLAYER_DASH_MULTIPLIER: float = 1.75
var PLAYER_DASH_DURATION: float = 0.75
var PLAYER_DASH_RECHARGE: float = 5.0
var PLAYER_MAX_DASHES: int = 1
var PLAYER_DASH_IMMUNITY_CHANCE: float = 1.0

# ============================================
# BASE ENEMY SETTINGS
# ============================================

var BASE_ENEMY_SPEED: float = 100.0
var BASE_ENEMY_HEALTH: int = 100
var BASE_ENEMY_DAMAGE: int = 10

# ============================================
# ENEMY SETTINGS
# ============================================

var ENEMY_SPEED: float = 100.0
var ENEMY_SIZE: float = 2.0

var ENEMY_MAX_HEALTH: int = 100
var ENEMY_HURT_DURATION: float = 0.5

var ENEMY_ATTACK_DISTANCE: float = 40.0
var ENEMY_ATTACK_DAMAGE: int = 10
var ENEMY_ATTACK_DURATION: float = 1.0

var ENEMY_SEPARATION_RADIUS: float = 25.0
var ENEMY_SEPARATION_STRENGTH: float = 2.0

var ENEMY_ALIGNMENT_RADIUS: float = 60.0
var ENEMY_ALIGNMENT_STRENGTH: float = 0.6

var ENEMY_COHESION_RADIUS: float = 100.0
var ENEMY_COHESION_STRENGTH: float = 0.5

var ENEMY_SEEK_GOAL_STRENGTH: float = 1.0
var ENEMY_SEEK_GOAL_RADIUS: float = 300.0
var ENEMY_SEEK_FAR_MIN: float = 0.01
var ENEMY_SEEK_FALLOFF: float = 2.0

var ENEMY_OBSTACLE_AVOID_DISTANCE: float = 35.0
var ENEMY_OBSTACLE_AVOID_STRENGTH: float = 1.5

var MAX_ENEMIES: int = 20
var ENEMY_SPAWN_INTERVAL: float = 0.75
var ENEMY_SPAWN_DISTANCE: float = 50.0

# ============================================
# BULLET SETTINGS
# ============================================

var BULLET_SPEED: float = 400.0
var BULLET_DAMAGE: int = 50
var BULLET_SIZE: float = 1.0

# ============================================
# GAME SETTINGS
# ============================================

var GAME_SPEED: float = 1.0

# ============================================
# READY
# ============================================

func _ready() -> void:
	apply_wave(wave_Data)

# ============================================
# APPLY NEW WAVE
# ============================================

func apply_wave(new_wave: Waves2) -> void:
	if new_wave == null:
		return

	# ============================================
	# STORE CURRENT WAVE
	# ============================================

	wave_Data = new_wave

	# ============================================
	# ENEMY STATS
	# ============================================

	ENEMY_SPEED = (BASE_ENEMY_SPEED * wave_Data.EneSpeedMult)
	ENEMY_MAX_HEALTH = (BASE_ENEMY_HEALTH * wave_Data.EneHealthMult)
	ENEMY_ATTACK_DAMAGE = (BASE_ENEMY_DAMAGE * wave_Data.EneDamMult)

	# ============================================
	# SPAWNING
	# ============================================

	MAX_ENEMIES = (wave_Data.SpawnMaxEne)
	ENEMY_SPAWN_INTERVAL = (wave_Data.SpawnInterval)

	print("Applied wave settings.")
	print("Enemy Speed: ",ENEMY_SPEED)
	print("Enemy Health: ",ENEMY_MAX_HEALTH)
	print("Enemy Damage: ",ENEMY_ATTACK_DAMAGE)
