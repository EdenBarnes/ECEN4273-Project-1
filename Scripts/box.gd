extends Node2D


# ============================================
# NODES
# ============================================

@onready var box_sprite: AnimatedSprite2D = $BoxSprite
@onready var weapon_display: AnimatedSprite2D = $WeaponDisplay
@onready var interaction_area: Area2D = $InteractionArea

var interaction_box: Control = null

# ============================================
# BOX SETTINGS
# ============================================

@export_category("Box Settings")

# How long the FINAL weapon stays available
# after the roulette finishes.
@export var open_duration: float = 5.0


# ============================================
# POSITION SETTINGS
# ============================================

@export_category("Position Settings")

@export var spawn_locations: Array[Marker2D]
@export var starting_location: int = 0

var current_location: int = 0


# ============================================
# WEAPON ROLL SETTINGS
# ============================================

@export_category("Weapon Roll")

# Put WeaponData resources here in the
# SAME ORDER as the WeaponDisplay frames.
@export var possible_weapons: Array[WeaponData]

# How fast the roulette starts.
@export var starting_roll_speed: float = 0.08

# How slow it gets before stopping.
@export var ending_roll_speed: float = 0.35

# How many weapon flashes happen before stopping.
@export var roll_count: int = 15

# ============================================
# PRICE SETTINGS
# ============================================

@export_category("Price Settings")

@export var starting_cost: int = 10
@export var cost_increase: int = 5

var current_cost: int = 0
var has_been_opened: bool = false


# ============================================
# STATE
# ============================================

var player_in_range: bool = false
var player = null

var is_opening: bool = false
var is_rolling: bool = false
var is_open: bool = false
var is_closing: bool = false

var selected_weapon: WeaponData = null

# Used to invalidate old open timers.
var current_roll_id: int = 0


# ============================================
# READY
# ============================================

const SFX_SPIN: AudioStream = preload("res://resources/Audio/World SFX/Box_wheel_spin.wav")
const SFX_REWARD: AudioStream = preload("res://resources/Audio/World SFX/Reward_jingle.wav")

var spin_sfx: AudioStreamPlayer = null
var reward_sfx: AudioStreamPlayer = null


func _ready() -> void:
	spin_sfx = Sfx.make(self, SFX_SPIN)
	reward_sfx = Sfx.make(self, SFX_REWARD)

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

	box_sprite.animation_finished.connect(_on_box_animation_finished)

	box_sprite.play("closed")

	weapon_display.visible = false
	weapon_display.stop()

	current_cost = starting_cost

	call_deferred("find_interaction_box")
	call_deferred("set_starting_position")


# ============================================
# STARTING POSITION
# ============================================

func set_starting_position() -> void:
	if spawn_locations.is_empty():
		print("ERROR: Gun Box has no spawn locations!")
		return

	current_location = clampi(starting_location, 0, spawn_locations.size() - 1)

	if spawn_locations[current_location] == null:
		print("ERROR: Starting Gun Box location is empty!")
		return

	global_position = spawn_locations[current_location].global_position


# ============================================
# INPUT
# ============================================

func _process(_delta: float) -> void:

	if not player_in_range:
		return

	if not Input.is_action_just_pressed("interact"):
		return


	# ============================================
	# OPEN CLOSED BOX
	# ============================================

	if (
		not is_opening
		and not is_open
		and not is_rolling
		and not is_closing
	):
		open_box()
		return


	# ============================================
	# TAKE SELECTED WEAPON
	# ============================================

	if (
		is_open
		and not is_rolling
		and selected_weapon != null
	):
		take_weapon()


# ============================================
# PLAYER DETECTION
# ============================================

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player_in_range = true
	player = body

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
# OPEN BOX
# ============================================

func open_box() -> void:
	if is_opening or is_open or is_rolling or is_closing:
		return

	if player == null:
		return

	# ============================================
	# CHECK COST
	# ============================================

	if not player.has_method("remove_coins"):
		return

	var purchase_successful: bool = player.remove_coins(current_cost)

	if not purchase_successful:
		if interaction_box != null:
			interaction_box.show_text("Not Enough Coins")
		return

	has_been_opened = true

	# ============================================
	# OPEN BOX
	# ============================================

	is_opening = true

	update_interaction_text()

	weapon_display.visible = false
	selected_weapon = null

	box_sprite.play("opening")


# ============================================
# BOX ANIMATION FINISHED
# ============================================

func _on_box_animation_finished() -> void:

	# ============================================
	# OPENING FINISHED
	# ============================================

	if box_sprite.animation == "opening":

		is_opening = false
		is_open = true

		# Leave the box on its final open frame.
		box_sprite.pause()

		start_weapon_roll()


	# ============================================
	# CLOSING FINISHED
	# ============================================

	elif box_sprite.animation == "closing":
		is_closing = false
		is_open = false

		weapon_display.visible = false
		selected_weapon = null

		box_sprite.play("closed")

		player_in_range = false
		player = null

		if interaction_box != null:
			interaction_box.hide_text()

		move_to_random_location()


# ============================================
# START WEAPON ROLL
# ============================================

func start_weapon_roll() -> void:

	if possible_weapons.is_empty():
		close_box()
		return

	is_rolling = true
	selected_weapon = null

	# Loops until the roll lands
	Sfx.start_loop(spin_sfx)

	weapon_display.visible = true


	# ============================================
	# PICK FINAL WEAPON
	# ============================================

	var final_weapon_index: int = randi_range(
		0,
		possible_weapons.size() - 1
	)

	selected_weapon = possible_weapons[
		final_weapon_index
	]


	# ============================================
	# ROULETTE EFFECT
	# ============================================

	for i in range(roll_count):

		# Cycle through available weapon sprites.
		var frame_index: int = (
			i % possible_weapons.size()
		)

		weapon_display.frame = frame_index


		# ========================================
		# SLOW DOWN ROULETTE
		# ========================================

		var progress: float = float(i) / float(
			max(1, roll_count - 1)
		)

		var delay: float = lerpf(
			starting_roll_speed,
			ending_roll_speed,
			progress
		)

		await get_tree().create_timer(delay).timeout


	# ============================================
	# SHOW FINAL WEAPON
	# ============================================

	weapon_display.frame = final_weapon_index

	is_rolling = false

	Sfx.stop_loop(spin_sfx)
	Sfx.play(reward_sfx, null, 1.0, 1.0)

	current_cost += cost_increase

	update_interaction_text()

	# ============================================
	# START OPEN TIMER
	# ============================================

	current_roll_id += 1

	var this_roll_id: int = current_roll_id

	start_open_timer(this_roll_id)


# ============================================
# OPEN TIMER
# ============================================

func start_open_timer(roll_id: int) -> void:

	# Wait while the final weapon is displayed.
	await get_tree().create_timer(
		open_duration
	).timeout


	# ============================================
	# CHECK IF TIMER IS STILL VALID
	# ============================================

	# If the player already took the weapon,
	# current_roll_id will have changed.
	if roll_id != current_roll_id:
		return

	# Weapon already removed.
	if selected_weapon == null:
		return

	# Box may already be closing.
	if is_closing:
		return


	# ============================================
	# REMOVE UNCLAIMED WEAPON
	# ============================================

	selected_weapon = null

	# Hide the gun BEFORE closing the box.
	weapon_display.visible = false


	# ============================================
	# CLOSE BOX
	# ============================================

	close_box()


# ============================================
# TAKE WEAPON
# ============================================

func take_weapon() -> void:

	if selected_weapon == null:
		return

	if player == null:
		return

	if not player.has_method("add_weapon"):
		return


	# ============================================
	# GIVE WEAPON TO PLAYER
	# ============================================

	var weapon_added: bool = player.add_weapon(
		selected_weapon
	)


	# ============================================
	# INVENTORY FULL
	# ============================================

	if not weapon_added:
		if interaction_box != null:
			interaction_box.show_text("Same Weapon Equipped")
		return


	# ============================================
	# WEAPON SUCCESSFULLY TAKEN
	# ============================================

	selected_weapon = null


	# Invalidate the open timer.
	current_roll_id += 1


	# Hide the weapon sprite.
	weapon_display.visible = false


	# Close the box.
	close_box()


# ============================================
# CLOSE BOX
# ============================================

func close_box() -> void:

	if is_closing:
		return

	is_open = false
	is_rolling = false
	is_closing = true

	update_interaction_text()

	# ============================================
	# REMOVE WEAPON DISPLAY
	# ============================================

	weapon_display.visible = false


	# ============================================
	# PLAY CLOSING ANIMATION
	# ============================================

	box_sprite.play("closing")

# ============================================
# UPDATE INTERACTION TEXT
# ============================================

func update_interaction_text() -> void:
	if interaction_box == null:
		return

	if not player_in_range:
		interaction_box.hide_text()
		return

	if is_opening or is_rolling:
		interaction_box.show_text("Rolling...")
		return

	if is_open and selected_weapon != null:
		interaction_box.show_text("Press \"E\" to Equip")
		return

	if is_closing:
		interaction_box.hide_text()
		return

	if has_been_opened:
		interaction_box.show_text("Open for " + str(current_cost) + " Coins?")
	else:
		interaction_box.show_text("Open for " + str(current_cost) + " Coins?\nPress \"E\" to Open")


# ============================================
# FIND INTERACTION BOX
# ============================================

func find_interaction_box() -> void:
	interaction_box = get_tree().get_first_node_in_group("interaction_box") as Control

	if interaction_box == null:
		print("ERROR: Gun Box could not find InteractionBox!")
	else:
		print("Gun Box found InteractionBox!")


# ============================================
# MOVE TO RANDOM LOCATION
# ============================================

func move_to_random_location() -> void:
	if spawn_locations.size() <= 1:
		return

	var new_location: int = current_location

	while new_location == current_location:
		new_location = randi_range(0, spawn_locations.size() - 1)

	if spawn_locations[new_location] == null:
		return

	current_location = new_location
	global_position = spawn_locations[current_location].global_position
