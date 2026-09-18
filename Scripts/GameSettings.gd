extends Node

 

var wave_Data = load("res://Waves/Wave1.tres")
# ============================================
# PLAYER SETTINGS
# ============================================

var PLAYER_SPEED: float = 150.0
var PLAYER_SIZE: float = 1.0
var PLAYER_MAX_HEALTH: int = 100
var PLAYER_INVULNERABILITY_DURATION: float = 2.0
var PLAYER_HURT_DURATION: float = 0.1
# ============================================
# ENEMY SETTINGS
# ============================================

var ENEMY_SPEED: float = 100.0 * wave_Data.EneSpeedMult
var ENEMY_SIZE: float = 2.0

var ENEMY_MAX_HEALTH: int = 100 * wave_Data.EneHealthMult
var ENEMY_HURT_DURATION: float = 0.5

var ENEMY_ATTACK_DISTANCE: float = 20.0
var ENEMY_ATTACK_DAMAGE: int = 10 * wave_Data.EneDamMult
var ENEMY_ATTACK_DURATION: float = 1.0

var ENEMY_SEPARATION_RADIUS: float = 100.0
var ENEMY_SEPARATION_STRENGTH: float = 20.0

var MAX_ENEMIES: int = wave_Data.SpawnMaxEne
var ENEMY_SPAWN_INTERVAL: float = wave_Data.SpawnInterval
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
