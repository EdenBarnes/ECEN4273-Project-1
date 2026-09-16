extends Area2D


# ============================================
# NODES
# ============================================

@onready var box_sprite: AnimatedSprite2D = $BoxSprite
@onready var weapon_display: AnimatedSprite2D = $WeaponDisplay


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

@export var starting_distance_from_player: float = 40.0


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

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	box_sprite.animation_finished.connect(
		_on_box_animation_finished
	)

	box_sprite.play("closed")

	weapon_display.visible = false
	weapon_display.stop()

	call_deferred("set_starting_position")


# ============================================
# STARTING POSITION
# ============================================

func set_starting_position() -> void:
	var player_node = get_tree().get_first_node_in_group("player")

	if player_node == null:
		return

	global_position = player_node.global_position + Vector2(
		0,
		-starting_distance_from_player
	)


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
	if body.is_in_group("player"):
		player_in_range = true
		player = body


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false

		if player == body:
			player = null


# ============================================
# OPEN BOX
# ============================================

func open_box() -> void:
	if is_opening or is_open or is_rolling or is_closing:
		return

	is_opening = true

	# Make sure an old weapon isn't visible.
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


# ============================================
# START WEAPON ROLL
# ============================================

func start_weapon_roll() -> void:

	if possible_weapons.is_empty():
		close_box()
		return

	is_rolling = true
	selected_weapon = null

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


	# ============================================
	# START OPEN TIMER
	# ============================================

	# Give this weapon roll a unique ID.
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


	# ============================================
	# REMOVE WEAPON DISPLAY
	# ============================================

	weapon_display.visible = false


	# ============================================
	# PLAY CLOSING ANIMATION
	# ============================================

	box_sprite.play("closing")
