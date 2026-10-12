extends Control


# ============================================
# NODES
# ============================================

@onready var health_sprite: AnimatedSprite2D = $Health
@onready var health_text: Label = $HealthText


# ============================================
# HEARTBEAT SETTINGS
# ============================================

@export var base_heartbeat_speed: float = 2.0
@export var heartbeat_growth: float = 1.18
@export var max_heartbeat_speed: float = 10.0

const DEAD_FRAME: int = 20


# ============================================
# HEALTH VARIABLES
# ============================================

var current_health: int = 100
var max_health: int = 100

var first_frame: int = 0
var second_frame: int = 1

var frame_timer: float = 0.0
var showing_second_frame: bool = false

var player: Node = null


# ============================================
# READY
# ============================================

func _ready() -> void:
	health_sprite.stop()
	health_sprite.animation = "health"

	call_deferred("connect_to_player")


# ============================================
# CONNECT TO PLAYER
# ============================================

func connect_to_player() -> void:
	player = get_tree().get_first_node_in_group("player")

	if player == null:
		print("ERROR: HealthDisplay could not find Player!")
		return

	if not player.health_changed.is_connected(update_health):
		player.health_changed.connect(update_health)

	# Set initial health
	update_health(player.current_health, player.max_health)


# ============================================
# PROCESS HEARTBEAT
# ============================================

func _process(delta: float) -> void:
	if current_health <= 0:
		health_sprite.frame = DEAD_FRAME
		return

	var health_percent: float = float(current_health) / float(max_health)
	health_percent = clampf(health_percent, 0.0, 1.0)

	# Determine which 10% health section we are in
	var health_section: int = int(floor((1.0 - health_percent) * 10.0))
	health_section = clampi(health_section, 0, 9)

	# Exponentially increase heartbeat speed as health decreases
	var current_heartbeat_speed: float = base_heartbeat_speed * pow(heartbeat_growth, health_section)
	current_heartbeat_speed = minf(current_heartbeat_speed, max_heartbeat_speed)

	var frame_time: float = 1.0 / current_heartbeat_speed

	frame_timer += delta

	if frame_timer >= frame_time:
		frame_timer = 0.0
		showing_second_frame = not showing_second_frame

		if showing_second_frame:
			health_sprite.frame = second_frame
		else:
			health_sprite.frame = first_frame


# ============================================
# UPDATE HEALTH
# ============================================

func update_health(new_health: int, new_max_health: int) -> void:
	current_health = new_health
	max_health = new_max_health

	# Don't display negative health
	health_text.text = str(maxi(current_health, 0))

	# ============================================
	# DEAD
	# ============================================

	if current_health <= 0:
		health_sprite.stop()
		health_sprite.frame = DEAD_FRAME
		return

	if max_health <= 0:
		return

	# ============================================
	# CALCULATE HEALTH PERCENT
	# ============================================

	var health_percent: float = float(current_health) / float(max_health)
	health_percent = clampf(health_percent, 0.0, 1.0)

	# ============================================
	# FIND FRAME PAIR
	# ============================================

	var health_section: int = int(floor((1.0 - health_percent) * 10.0))
	health_section = clampi(health_section, 0, 9)

	first_frame = health_section * 2
	second_frame = first_frame + 1

	# Immediately show first frame
	showing_second_frame = false
	frame_timer = 0.0

	health_sprite.animation = "health"
	health_sprite.frame = first_frame
