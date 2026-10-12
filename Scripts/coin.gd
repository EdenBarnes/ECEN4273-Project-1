extends Area2D


# ============================================
# NODES
# ============================================

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D


# ============================================
# COIN SETTINGS
# ============================================

@export var coin_value: int = 1


# ============================================
# MAGNET SETTINGS
# ============================================

@export var magnet_start_speed: float = 100.0
@export var magnet_acceleration: float = 800.0
@export var magnet_max_speed: float = 700.0
@export var collect_distance: float = 10.0


# ============================================
# SCATTER SETTINGS
# ============================================

@export var scatter_distance_min: float = 10.0
@export var scatter_distance_max: float = 35.0
@export var scatter_time: float = 0.4
@export var jump_height_min: float = 15.0
@export var jump_height_max: float = 30.0


# ============================================
# VARIABLES
# ============================================

var can_collect: bool = false

var magnet_active: bool = false
var magnet_speed: float = 0.0
var magnet_target: Node2D = null

var movement_tween: Tween = null
var jump_tween: Tween = null


# ============================================
# READY
# ============================================

func _ready() -> void:
	add_to_group("coins")

	body_entered.connect(_on_body_entered)

	collision.set_deferred("disabled", true)


# ============================================
# SCATTER
# ============================================

func scatter() -> void:
	var random_angle: float = randf_range(0.0, TAU)
	var random_distance: float = randf_range(scatter_distance_min, scatter_distance_max)
	var scatter_direction: Vector2 = Vector2.from_angle(random_angle)
	var target_position: Vector2 = global_position + scatter_direction * random_distance
	var jump_height: float = randf_range(jump_height_min, jump_height_max)

	# Move coin across the ground.
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_QUAD)
	movement_tween.set_ease(Tween.EASE_OUT)
	movement_tween.tween_property(self, "global_position", target_position, scatter_time)

	# Move the sprite upward to fake height.
	jump_tween = create_tween()
	jump_tween.tween_property(sprite, "position:y", -jump_height, scatter_time * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Drop the sprite back onto the ground.
	jump_tween.tween_property(sprite, "position:y", 0.0, scatter_time * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await movement_tween.finished

	# Don't re-enable normal collection if the
	# coin has already started magnet movement.
	if magnet_active:
		return

	can_collect = true
	collision.set_deferred("disabled", false)


# ============================================
# NORMAL COLLECTION
# ============================================

func _on_body_entered(body: Node2D) -> void:
	if not can_collect:
		return

	if not body.is_in_group("player"):
		return

	magnet_target = body
	collect_coin()


# ============================================
# COLLECT COIN
# ============================================

const SFX_COIN: AudioStream = preload("res://resources/Audio/Player SFX/Coin_pickup.wav")


func collect_coin() -> void:
	if not is_instance_valid(magnet_target):
		return

	if not magnet_target.has_method("add_coins"):
		return

	magnet_target.add_coins(coin_value)

	# Played on a throwaway node parented to the
	# scene: this coin calls queue_free() a moment
	# later and would cut its own sound off.
	var pickup := AudioStreamPlayer.new()
	pickup.stream = SFX_COIN
	pickup.bus = "SFX"
	pickup.pitch_scale = randf_range(0.96, 1.08)
	get_tree().current_scene.add_child(pickup)
	pickup.finished.connect(pickup.queue_free)
	pickup.play()

	can_collect = false
	magnet_active = false
	collision.set_deferred("disabled", true)

	queue_free()


# ============================================
# MAGNET MOVEMENT
# ============================================

func _process(delta: float) -> void:
	if not magnet_active:
		return

	if not is_instance_valid(magnet_target):
		magnet_active = false
		return

	magnet_speed = minf(
		magnet_speed + magnet_acceleration * delta,
		magnet_max_speed
	)

	var direction: Vector2 = global_position.direction_to(
		magnet_target.global_position
	)

	global_position += direction * magnet_speed * delta

	if global_position.distance_to(magnet_target.global_position) <= collect_distance:
		collect_coin()


# ============================================
# START MAGNET
# ============================================

func move_to_player(player_node: Node2D) -> void:
	if not is_instance_valid(player_node):
		return

	# Stop the scatter animation if the wave
	# ends before this coin finishes landing.
	if movement_tween != null and movement_tween.is_valid():
		movement_tween.kill()

	if jump_tween != null and jump_tween.is_valid():
		jump_tween.kill()

	# Put the sprite back on its ground position.
	sprite.position.y = 0.0

	magnet_target = player_node
	magnet_speed = magnet_start_speed
	magnet_active = true
	can_collect = true

	collision.set_deferred("disabled", false)
