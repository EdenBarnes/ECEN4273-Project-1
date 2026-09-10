extends CharacterBody2D

@onready var anim_tree: AnimationTree = $Sprite2D/AnimationTree
@onready var anim_player: AnimationPlayer = $Sprite2D/AnimationPlayer
@onready var state_machine: AnimationNodeStateMachinePlayback = anim_tree["parameters/playback"]
@onready var hurt_timer: Timer = $HurtTimer
@onready var attack_timer: Timer = $AttackTimer

@export var speed := 25.0
@export var hurt_duration := 0.5
@export var attack_distance := 10.0
@export var attack_damage := 10
@export var attack_duration := 1.0
@export var max_health := 100
@export var separation_radius := 50.0
@export var separation_strength := 5.0
var current_health := max_health

var movement_direction := Vector2.DOWN
var facing_direction := Vector2.DOWN
var is_locked := false
var is_dead := false

var player: CharacterBody2D

func _ready():
	anim_tree.active = true
	
	hurt_timer.one_shot = true
	hurt_timer.wait_time = hurt_duration
	hurt_timer.timeout.connect(_on_hurt_timer_timeout)
	
	attack_timer.one_shot = true
	attack_timer.wait_time = attack_duration
		
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if is_locked:
		return
		
	if player:
		var player_offset = player.global_position - global_position

		var enemy_separation = get_separation_vector(separation_radius) * separation_strength
		var player_separation = get_player_separation(attack_distance) * separation_strength

		if player_offset.length() >= attack_distance:
			velocity = (player_offset.normalized() * speed + enemy_separation).normalized() * speed * (current_health * 1.0 / max_health)
		else:
			velocity = (player_separation + enemy_separation).normalized() * speed * (current_health * 1.0 / max_health)
			attack(player)
			
		facing_direction = velocity.normalized()
		
	if velocity.length() != 0.0:
		movement_direction = velocity.normalized()
		travel_to("walk")
	else:
		travel_to("idle")

	move_and_slide()
	
func get_separation_vector(radius: float) -> Vector2:
	var push := Vector2.ZERO
	var enemies = get_tree().get_nodes_in_group("enemies")

	for other in enemies:
		if other == self:
			continue
		var dist = global_position.distance_to(other.global_position)
		if dist < radius and dist > 0:
			var away = (global_position - other.global_position).normalized()
			push += away * (radius - dist) / radius

	return push
	
func get_player_separation(radius: float) -> Vector2:
	if not player:
		return Vector2.ZERO
	var dist = global_position.distance_to(player.global_position)
	if dist < radius and dist > 0:
		var away = (global_position - player.global_position).normalized()
		return away * (radius - dist) / radius
	return Vector2.ZERO
	
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
		
func attack(character: CharacterBody2D):
	if !attack_timer.is_stopped():
		return
		
	if character.has_method("take_damage"):
		attack_timer.start()
		character.take_damage(attack_damage)
		
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
