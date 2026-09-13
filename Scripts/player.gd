extends CharacterBody2D

const BULLET_SCENE = preload("res://Scenes/bullet.tscn")

@onready var anim_tree: AnimationTree = $Sprite2D/AnimationTree
@onready var anim_player: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var state_machine: AnimationNodeStateMachinePlayback = anim_tree["parameters/playback"]
@onready var hurt_timer: Timer = $HurtTimer

var speed: float = 50.0
var hurt_duration: float = 0.5
var max_health: int = 100
var current_health: int = 100

var movement_direction := Vector2.DOWN
var facing_direction := Vector2.DOWN
var is_locked := false
var is_dead := false


func _ready():
	# Load values from GameSettings
	speed = GameSettings.PLAYER_SPEED
	hurt_duration = GameSettings.PLAYER_HURT_DURATION
	max_health = GameSettings.PLAYER_MAX_HEALTH
	current_health = max_health

	# Player size
	scale = Vector2.ONE * GameSettings.PLAYER_SIZE

	anim_tree.active = true

	hurt_timer.one_shot = true
	hurt_timer.wait_time = hurt_duration
	hurt_timer.timeout.connect(_on_hurt_timer_timeout)

	# Spawn player in middle of window
	position = get_viewport_rect().size / 2.0

func _physics_process(_delta: float) -> void:
	if is_locked:
		return

	var input_vector := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	
	var mouse_pos: Vector2 = get_global_mouse_position()
	facing_direction = (mouse_pos - global_position).normalized()
	
	if input_vector != Vector2.ZERO:
		movement_direction = input_vector.normalized()
		velocity = movement_direction * speed
		travel_to("walk")
	else:
		velocity = Vector2.ZERO
		travel_to("idle")
		
	if Input.is_action_just_pressed("shoot"):
		shoot()

	move_and_slide()
	
func take_damage(amount: int):
	if is_dead:
		return
	
	current_health -= amount
	if current_health <= 0 && !is_dead:
		die()
		return
		
	is_locked = true
	travel_to("hurt");
	
	hurt_timer.start()

func _on_hurt_timer_timeout():
	if !is_dead:
		is_locked = false
		

func die():
	is_locked = true
	is_dead = true
	travel_to("death")
	await get_tree().create_timer(5.0).timeout
	queue_free()

func travel_to(state_name: String):
	if state_machine.get_current_node() != state_name:
		state_machine.travel(state_name)
	# Always keep blend_position updated so direction stays current
	anim_tree.set("parameters/" + state_name + "/blend_position", facing_direction)

func shoot():
	var bullet = BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = $MuzzlePosition.global_position	
	bullet.direction = facing_direction
