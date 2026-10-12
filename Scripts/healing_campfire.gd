
extends Node2D

# ============================================
# NODES
# ============================================

@onready var campfire: AnimatedSprite2D = $Campfire/Sprite
@onready var interaction_area: Area2D = $InteractionArea

@onready var stump_1: AnimatedSprite2D = $Stump1/Sprite
@onready var stump_2: AnimatedSprite2D = $Stump2/Sprite
@onready var stump_3: AnimatedSprite2D = $Stump3/Sprite
@onready var stump_4: AnimatedSprite2D = $Stump4/Sprite

var interaction_box: Control = null
var wave_manager: Node = null

# ============================================
# HEALING SETTINGS
# ============================================

@export_category("Healing Settings")

@export var max_heals: int = 4
@export var heal_percent: float = 0.25

# ============================================
# FIRE ANIMATION SETTINGS
# ============================================

@export_category("Fire Animation Settings")

@export var fire_frame_time: float = 0.2
@export var stump_start_delay: float = 0.10

var fire_frame_timer: float = 0.0
var last_fire_frame: int = -1

# ============================================
# COST SETTINGS
# ============================================

@export_category("Cost Settings")

@export var starting_cost: int = 15
@export var cost_increase: int = 25
@export var restock_cost_per_heal: int = 5

var current_cost: int = 0

# ============================================
# STATE
# ============================================

var player: Node = null

var player_in_range: bool = false
var is_lit: bool = false
var is_activating: bool = false
var fire_active: bool = false
var has_been_lit: bool = false

var heals_remaining: int = 0

# ============================================
# SOUNDS
# ============================================

const SFX_FIRE: AudioStream = preload("res://resources/Audio/World SFX/Fire_whoosh.wav")
const SFX_HEAL: AudioStream = preload("res://resources/Audio/World SFX/Heal.wav")

var sfx: AudioStreamPlayer = null

# ============================================
# READY
# ============================================

func _ready() -> void:
	sfx = Sfx.make(self)

	current_cost = starting_cost

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

	stump_1.animation_finished.connect(_on_stump_1_finished)
	stump_2.animation_finished.connect(_on_stump_2_finished)
	stump_3.animation_finished.connect(_on_stump_3_finished)
	stump_4.animation_finished.connect(_on_stump_4_finished)

	reset_campfire()

	call_deferred("find_references")

# ============================================
# PROCESS
# ============================================

func _process(delta: float) -> void:
	update_fire_animation(delta)

	if not player_in_range:
		return

	if is_activating:
		return

	# Refresh text as player health or wave state changes.
	update_interaction_text()

	if not Input.is_action_just_pressed("interact"):
		return

	# Between waves, a full-health player can restock
	# a previously purchased campfire.
	if can_restock():
		restock_campfire()
		return

	# A lit campfire can heal during or between waves.
	if is_lit:
		use_heal()
		return

	# An unlit campfire can only be purchased
	# between waves.
	if not can_light_campfire():
		update_interaction_text()
		return

	light_campfire()

# ============================================
# PLAYER DETECTION
# ============================================

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player = body
	player_in_range = true

	update_interaction_text()


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = false

	if player == body:
		player = null

	if interaction_box != null:
		interaction_box.hide_text()

# ============================================
# CAN LIGHT CAMPFIRE
# ============================================

func can_light_campfire() -> bool:
	if wave_manager == null:
		return false

	return wave_manager.is_between_waves()

# ============================================
# LIGHT CAMPFIRE
# ============================================

func light_campfire() -> void:
	if player == null:
		return

	if not can_light_campfire():
		update_interaction_text()
		return

	if not player.has_method("remove_coins"):
		return

	var purchase_successful: bool = player.remove_coins(current_cost)

	if not purchase_successful:
		if interaction_box != null:
			interaction_box.show_text("Not Enough Coins")
		return

	is_activating = true
	fire_active = true
	has_been_lit = true
	heals_remaining = max_heals

	campfire.animation = "CampfireOn"
	campfire.pause()

	fire_frame_timer = 0.0
	last_fire_frame = -1

	start_stump_animations()

	Sfx.play(sfx, SFX_FIRE)

	# Increase cost for the next normal activation.
	current_cost += cost_increase

	update_interaction_text()

# ============================================
# RESTOCK HELPERS
# ============================================

func is_player_full_health() -> bool:
	if player == null:
		return false

	var current_hp: int = int(player.get("current_health"))
	var maximum_hp: int = int(player.get("max_health"))

	return maximum_hp > 0 and current_hp >= maximum_hp


func get_restock_cost() -> int:
	var missing_heals: int = maxi(max_heals - heals_remaining, 0)
	return missing_heals * restock_cost_per_heal


func can_restock() -> bool:
	if not has_been_lit:
		return false

	if is_activating:
		return false

	if not can_light_campfire():
		return false

	if not is_player_full_health():
		return false

	return heals_remaining < max_heals

# ============================================
# RESTOCK CAMPFIRE
# ============================================

func restock_campfire() -> void:
	if player == null:
		return

	if not can_restock():
		return

	if not player.has_method("remove_coins"):
		return

	var restock_cost: int = get_restock_cost()
	var purchase_successful: bool = player.remove_coins(restock_cost)

	if not purchase_successful:
		if interaction_box != null:
			interaction_box.show_text("Not Enough Coins")
		return

	# Restore all available heals.
	heals_remaining = max_heals

	# Restore the stump animations.
	stump_1.play("StumpIdle")
	stump_2.play("StumpIdle")
	stump_3.play("StumpIdle")
	stump_4.play("StumpIdle")

	# Relight the fire if all heals had been used.
	if not is_lit:
		is_lit = true
		fire_active = true

		campfire.animation = "CampfireOn"
		campfire.pause()

		fire_frame_timer = 0.0
		last_fire_frame = -1

		Sfx.play(sfx, SFX_FIRE)
	else:
		Sfx.play(sfx, SFX_HEAL)

	update_interaction_text()

# ============================================
# RANDOM FIRE ANIMATION
# ============================================

func update_fire_animation(delta: float) -> void:
	if not fire_active:
		return

	fire_frame_timer -= delta

	if fire_frame_timer > 0.0:
		return

	fire_frame_timer = fire_frame_time

	var frame_count: int = campfire.sprite_frames.get_frame_count("CampfireOn")

	if frame_count <= 1:
		return

	var new_frame: int = randi_range(0, frame_count - 1)

	while new_frame == last_fire_frame:
		new_frame = randi_range(0, frame_count - 1)

	last_fire_frame = new_frame
	campfire.frame = new_frame

# ============================================
# STUMP START FINISHED
# ============================================

func _on_stump_1_finished() -> void:
	if stump_1.animation == "StumpStart":
		stump_1.play("StumpIdle")
		check_activation_finished()


func _on_stump_2_finished() -> void:
	if stump_2.animation == "StumpStart":
		stump_2.play("StumpIdle")
		check_activation_finished()


func _on_stump_3_finished() -> void:
	if stump_3.animation == "StumpStart":
		stump_3.play("StumpIdle")
		check_activation_finished()


func _on_stump_4_finished() -> void:
	if stump_4.animation == "StumpStart":
		stump_4.play("StumpIdle")
		check_activation_finished()

# ============================================
# CHECK ACTIVATION
# ============================================

func check_activation_finished() -> void:
	if stump_1.animation != "StumpIdle":
		return

	if stump_2.animation != "StumpIdle":
		return

	if stump_3.animation != "StumpIdle":
		return

	if stump_4.animation != "StumpIdle":
		return

	is_activating = false
	is_lit = true

	update_interaction_text()

# ============================================
# USE HEAL
# ============================================

func use_heal() -> void:
	if player == null:
		return

	if heals_remaining <= 0:
		return

	if not player.has_method("heal"):
		return

	var heal_successful: bool = player.heal(heal_percent)

	if not heal_successful:
		if interaction_box != null:
			interaction_box.show_text("Health Full")
		return

	Sfx.play(sfx, SFX_HEAL)

	heals_remaining -= 1

	update_stumps()

	if heals_remaining <= 0:
		turn_off_campfire()
	else:
		update_interaction_text()

# ============================================
# UPDATE STUMPS
# ============================================

func update_stumps() -> void:
	if heals_remaining < 4:
		stump_4.play("StumpOff")

	if heals_remaining < 3:
		stump_3.play("StumpOff")

	if heals_remaining < 2:
		stump_2.play("StumpOff")

	if heals_remaining < 1:
		stump_1.play("StumpOff")

# ============================================
# TURN OFF CAMPFIRE
# ============================================

func turn_off_campfire() -> void:
	is_lit = false
	is_activating = false
	fire_active = false
	heals_remaining = 0

	fire_frame_timer = 0.0
	last_fire_frame = -1

	campfire.play("CampfireOff")

	stump_1.play("StumpOff")
	stump_2.play("StumpOff")
	stump_3.play("StumpOff")
	stump_4.play("StumpOff")

	update_interaction_text()

# ============================================
# RESET CAMPFIRE
# ============================================

func reset_campfire() -> void:
	is_lit = false
	is_activating = false
	fire_active = false
	has_been_lit = false
	heals_remaining = 0

	fire_frame_timer = 0.0
	last_fire_frame = -1

	campfire.play("CampfireOff")

	stump_1.play("StumpOff")
	stump_2.play("StumpOff")
	stump_3.play("StumpOff")
	stump_4.play("StumpOff")

# ============================================
# WAVE STATE
# ============================================

func _on_wave_countdown_started(_wave_number: int, _duration: float) -> void:
	update_interaction_text()


func _on_wave_started(_wave_number: int) -> void:
	update_interaction_text()

# ============================================
# INTERACTION TEXT
# ============================================

func update_interaction_text() -> void:
	if interaction_box == null:
		return

	if not player_in_range:
		return

	if is_activating:
		interaction_box.show_text("Lighting Campfire...")
		return

	# During active waves, preserve normal behavior.
	if not can_light_campfire():
		if is_lit:
			interaction_box.show_text(
				"Heals: " + str(heals_remaining) + " / " + str(max_heals) +
				"\nPress \"E\" to Heal " + str(int(heal_percent * 100.0)) + "%"
			)
		else:
			interaction_box.show_text("Light Campfire Between Waves!")
		return

	# Between waves, show restock only if the
	# player is at full health and heals are missing.
	if can_restock():
		interaction_box.show_text(
			"Restock Campfire: " + str(get_restock_cost()) +
			" Coins\nPress \"E\" to Restock"
		)
		return

	# Lit campfire with available heals.
	if is_lit:
		interaction_box.show_text(
			"Heals: " + str(heals_remaining) + " / " + str(max_heals) +
			"\nPress \"E\" to Heal " + str(int(heal_percent * 100.0)) + "%"
		)
		return

	# Unlit campfire, including one that is
	# depleted while the player is injured.
	interaction_box.show_text(
		"Cost: " + str(current_cost) +
		" Coins\nPress \"E\" to Light"
	)

# ============================================
# FIND REFERENCES
# ============================================

func find_references() -> void:
	interaction_box = get_tree().get_first_node_in_group("interaction_box") as Control
	wave_manager = get_tree().get_first_node_in_group("wave_manager")

	if interaction_box == null:
		print("ERROR: Healing Campfire could not find InteractionBox!")

	if wave_manager == null:
		print("ERROR: Healing Campfire could not find WaveManager!")
		return

	wave_manager.wave_countdown_started.connect(_on_wave_countdown_started)
	wave_manager.wave_started.connect(_on_wave_started)

	update_interaction_text()

# ============================================
# STAGGER STUMP ANIMATIONS
# ============================================

func start_stump_animations() -> void:
	stump_1.play("StumpStart")

	await get_tree().create_timer(stump_start_delay).timeout
	stump_2.play("StumpStart")

	await get_tree().create_timer(stump_start_delay).timeout
	stump_3.play("StumpStart")

	await get_tree().create_timer(stump_start_delay).timeout
	stump_4.play("StumpStart")
