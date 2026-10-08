class_name EnemyData
extends Resource


@export var display_name: String = "Zombie"

@export_group("Stats (multipliers of GameSettings base values)")
@export var speed_mult: float = 1.0
@export var health_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var attack_distance_mult: float = 1.0
@export var size_mult: float = 1.0

@export_group("Coins")
@export var coin_drop_min: int = 1
@export var coin_drop_max: int = 1

@export_group("Hurt behavior")
## Stun (hurt animation + lock) on every hit that doesn't kill.
@export var stun_on_every_hit: bool = true
## Health fractions that trigger a stun when crossed, e.g. [0.75, 0.5, 0.25]. Must be descending.
@export var stun_thresholds: Array[float] = []
@export var flash_on_hit: bool = false

@export_group("Boss")
@export var is_boss: bool = false
## Read speed/health/damage/reach/size from the current wave (BossSpeed, Bosshealth, etc.)
@export var use_wave_boss_stats: bool = false

@export_group("Visuals")
## Library containing idle/walk/hurt/death animations using this type's textures.
## Animation names must match the ones the AnimationTree expects.
@export var animation_library: AnimationLibrary
