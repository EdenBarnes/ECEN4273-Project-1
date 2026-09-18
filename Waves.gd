class_name Waves2
extends Resource

@export_category("Enemy_Sats")
@export var EneDamMult: int =  1
@export var EneSpeedMult: float = 1.0
@export var EneHealthMult: int = 1

@export_category("Spawn_Sett")
@export var SpawnInterval: float = 0.75
@export var SpawnMaxEne: int = 20

@export_category("type_Rates")
@export var Sprintper: int = 0 #pick One and a Hundrend
@export var bigper: int = 0
@export var normalper: int = 100

@export_category("Boss")
@export var Bossspawn: bool = false
@export var Bosshealth: int = 0
@export var BossSpeed: int = 0
@export var BossSize: int = 0
@export var BossDam: int = 0
@export var Bossreach: int = 0
