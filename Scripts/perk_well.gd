extends Node2D


# ============================================
# WELL STATE
# ============================================

enum WellState {
	INACTIVE,
	AVAILABLE,
	MOVING_PLAYER,
	ACTIVATING,
	COIN_FLYING,
	WAITING_FOR_CLICK,
	PERK_MENU
}

var state: WellState = WellState.INACTIVE


# ============================================
# NODES
# ============================================

@onready var well_sprite: AnimatedSprite2D = $Well/Sprite
@onready var perk_coin_display: Area2D = $PerkCoinDisplay
@onready var perk_coin: AnimatedSprite2D = $PerkCoinDisplay/Coin
@onready var interaction_area: Area2D = $InteractionArea
@onready var coin_spawn_position: Marker2D = $CoinSpawnPosition
@onready var left_player_position: Marker2D = $LeftPlayerPosition
@onready var right_player_position: Marker2D = $RightPlayerPosition


# ============================================
# REFERENCES
# ============================================

var player: CharacterBody2D = null
var wave_manager: Node = null
var interaction_box: Control = null
var perk_hud: Control = null


# ============================================
# COST SETTINGS
# ============================================

@export_category("Cost Settings")

@export var starting_cost: int = 5
@export var cost_increase: int = 3

var current_cost: int = 0


# ============================================
# PLAYER MOVEMENT SETTINGS
# ============================================

@export_category("Player Movement")

@export var player_walk_speed: float = 60.0
@export var player_stop_distance: float = 2.0

var target_player_position: Vector2 = Vector2.ZERO
var interaction_side: String = ""


# ============================================
# COIN MOVEMENT SETTINGS
# ============================================

@export_category("Coin Movement")

@export var coin_hover_height: float = 55.0
@export var coin_arc_height: float = 55.0
@export var coin_travel_time: float = 0.8
@export var hover_amount: float = 3.0
@export var hover_speed: float = 3.0

var coin_arc_start: Vector2 = Vector2.ZERO
var coin_arc_control: Vector2 = Vector2.ZERO
var coin_arc_end: Vector2 = Vector2.ZERO

var coin_arc_progress: float = 0.0
var hover_time: float = 0.0
var coin_hover_position: Vector2 = Vector2.ZERO


# ============================================
# PERK POOLS
# ============================================

var common_perks: Array[String] = [
	"Ammo_Coin",
	"Health_Coin",
	"Dmg_Coin",
	"Dash_Coin"
]

var epic_perks: Array[String] = [
	"Reload_Coin",
	"Aim_Coin",
	"Firerate_Coin"
]

var legendary_perks: Array[String] = [
	"Bounce_Coin",
	"Bullet_Coin",
	"Pierce_Coin"
]

var selected_perk: String = ""
var selected_rarity: String = ""


# ============================================
# READY
# ============================================

const SFX_CHAIN: AudioStream = preload("res://resources/Audio/World SFX/Well_chain_loop.wav")
const SFX_REWARD: AudioStream = preload("res://resources/Audio/World SFX/Reward_jingle.wav")

var chain_sfx: AudioStreamPlayer = null
var reward_sfx: AudioStreamPlayer = null


func _ready() -> void:
	chain_sfx = Sfx.make(self, SFX_CHAIN)
	reward_sfx = Sfx.make(self, SFX_REWARD)

	current_cost = starting_cost

	perk_coin_display.visible = false
	well_sprite.play("Idle")

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	well_sprite.animation_finished.connect(_on_well_animation_finished)

	call_deferred("find_references")


# ============================================
# PROCESS
# ============================================

func _process(delta: float) -> void:
	if state == WellState.MOVING_PLAYER:
		move_player_to_marker(delta)
		return

	if state == WellState.COIN_FLYING:
		update_coin_arc(delta)
		return

	if state == WellState.WAITING_FOR_CLICK:
		update_coin_hover(delta)

		if Input.is_action_just_pressed("interact"):
			open_perk_menu()

		return

	if state != WellState.AVAILABLE:
		return

	if player == null:
		return

	if not Input.is_action_just_pressed("interact"):
		return

	start_well_interaction()


# ============================================
# FIND REFERENCES
# ============================================

func find_references() -> void:
	wave_manager = get_tree().get_first_node_in_group("wave_manager")
	interaction_box = get_tree().get_first_node_in_group("interaction_box") as Control
	perk_hud = get_tree().get_first_node_in_group("perk_hud") as Control

	if wave_manager == null:
		print("ERROR: PerkWell could not find WaveManager!")
		return

	if interaction_box == null:
		print("ERROR: PerkWell could not find InteractionBox!")

	if perk_hud == null:
		print("ERROR: PerkWell could not find PerkHUD!")
	else:
		if perk_hud.has_signal("perk_selection_completed"):
			perk_hud.perk_selection_completed.connect(_on_perk_selection_completed)

	wave_manager.wave_countdown_started.connect(_on_wave_countdown_started)
	wave_manager.wave_started.connect(_on_wave_started)

	update_well_availability()


# ============================================
# WAVE STATE
# ============================================

func _on_wave_countdown_started(_wave_number: int, _duration: float) -> void:
	update_well_availability()

	if player != null:
		update_interaction_text()


func _on_wave_started(_wave_number: int) -> void:
	update_well_availability()

	if player != null and interaction_box != null:
		interaction_box.hide_text()


# ============================================
# PLAYER ENTER / EXIT
# ============================================

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	player = body as CharacterBody2D

	update_well_availability()
	update_interaction_text()


func _on_body_exited(body: Node2D) -> void:
	if body != player:
		return

	if state != WellState.AVAILABLE and state != WellState.INACTIVE:
		return

	player = null

	if interaction_box != null:
		interaction_box.hide_text()


# ============================================
# WELL AVAILABILITY
# ============================================

func update_well_availability() -> void:
	if state != WellState.INACTIVE and state != WellState.AVAILABLE:
		return

	if wave_manager == null:
		state = WellState.INACTIVE
		return

	if wave_manager.is_between_waves():
		state = WellState.AVAILABLE
	else:
		state = WellState.INACTIVE


# ============================================
# INTERACTION TEXT
# ============================================

func update_interaction_text() -> void:
	if interaction_box == null:
		return

	if player == null:
		return

	if state == WellState.INACTIVE:
		interaction_box.hide_text()
		return

	if state == WellState.AVAILABLE:
		interaction_box.show_text("Cost: " + str(current_cost) + " Coins\nPress \"E\" to Buy Perk")
		return

	if state == WellState.WAITING_FOR_CLICK:
		interaction_box.show_text("Press \"E\" to View Perk")
		return

	interaction_box.hide_text()



# ============================================
# START WELL INTERACTION
# ============================================

func start_well_interaction() -> void:
	if player == null:
		return

	if wave_manager == null:
		return

	if not wave_manager.is_between_waves():
		return

	if not player.has_method("remove_coins"):
		return

	var purchase_successful: bool = player.remove_coins(current_cost)

	if not purchase_successful:
		if interaction_box != null:
			interaction_box.show_text("Not Enough Coins")
		return

	# Increase cost for the next purchase.
	current_cost += cost_increase

	wave_manager.pause_wave_countdown()

	lock_player()
	hide_player_weapon()

	roll_perk()
	choose_interaction_side()

	state = WellState.MOVING_PLAYER

	update_interaction_text()



# ============================================
# CHOOSE SIDE
# ============================================

func choose_interaction_side() -> void:
	if player.global_position.x < global_position.x:
		interaction_side = "left"
		target_player_position = left_player_position.global_position
	else:
		interaction_side = "right"
		target_player_position = right_player_position.global_position


# ============================================
# LOCK PLAYER
# ============================================

func lock_player() -> void:
	if player == null:
		return

	player.set("is_locked", true)
	player.velocity = Vector2.ZERO


# ============================================
# UNLOCK PLAYER
# ============================================

func unlock_player() -> void:
	if player == null:
		return

	player.velocity = Vector2.ZERO
	player.set("is_locked", false)


# ============================================
# PLAYER WEAPON
# ============================================

func hide_player_weapon() -> void:
	if player == null:
		return

	var weapon_holder: Node = player.get_node_or_null("WeaponHolder")

	if weapon_holder != null:
		weapon_holder.visible = false


func show_player_weapon() -> void:
	if player == null:
		return

	var weapon_holder: Node = player.get_node_or_null("WeaponHolder")

	if weapon_holder != null:
		weapon_holder.visible = true


# ============================================
# MOVE PLAYER TO MARKER
# ============================================

func move_player_to_marker(delta: float) -> void:
	if player == null:
		return

	var distance: float = player.global_position.distance_to(target_player_position)

	if distance <= player_stop_distance:
		player.global_position = target_player_position
		player.velocity = Vector2.ZERO

		if player.has_method("travel_to"):
			player.travel_to("idle")

		start_well_animation()
		return

	var direction: Vector2 = player.global_position.direction_to(target_player_position)

	player.velocity = direction * player_walk_speed
	player.global_position = player.global_position.move_toward(target_player_position, player_walk_speed * delta)

	update_player_direction(direction)

	if player.has_method("travel_to"):
		player.travel_to("walk")


# ============================================
# UPDATE PLAYER DIRECTION
# ============================================

func update_player_direction(direction: Vector2) -> void:
	if player == null:
		return

	player.set("movement_direction", direction)
	player.set("facing_direction", direction)


# ============================================
# FACE WELL
# ============================================

func face_player_toward_well() -> void:
	if player == null:
		return

	var direction: Vector2 = player.global_position.direction_to(global_position)

	player.velocity = Vector2.ZERO

	update_player_direction(direction)

	if player.has_method("travel_to"):
		player.travel_to("idle")


# ============================================
# FACE PLAYER FORWARD
# ============================================

func face_player_forward() -> void:
	if player == null:
		return

	var forward_direction: Vector2 = Vector2.DOWN

	player.velocity = Vector2.ZERO

	player.set("movement_direction", forward_direction)
	player.set("facing_direction", forward_direction)

	if player.has_method("travel_to"):
		player.travel_to("idle")


# ============================================
# START WELL ANIMATION
# ============================================

func start_well_animation() -> void:
	state = WellState.ACTIVATING

	player.velocity = Vector2.ZERO

	face_player_toward_well()

	if interaction_side == "left":
		well_sprite.play("LeftSide")
	else:
		well_sprite.play("RightSide")

	# Loops for however long the crank animation runs
	Sfx.start_loop(chain_sfx)

	update_interaction_text()


# ============================================
# WELL ANIMATION FINISHED
# ============================================

func _on_well_animation_finished() -> void:
	if state != WellState.ACTIVATING:
		return

	if well_sprite.animation != "LeftSide" and well_sprite.animation != "RightSide":
		return

	Sfx.stop_loop(chain_sfx)
	Sfx.play(reward_sfx, null, 1.0, 1.0)

	start_coin_arc()


# ============================================
# ROLL PERK
# ============================================

func roll_perk() -> void:
	var roll: float = randf()

	if roll < 0.60:
		selected_rarity = "Common"
		selected_perk = common_perks.pick_random()

	elif roll < 0.90:
		selected_rarity = "Epic"
		selected_perk = epic_perks.pick_random()

	else:
		selected_rarity = "Legendary"
		selected_perk = legendary_perks.pick_random()

	print("PERK ROLLED: ", selected_perk, " | RARITY: ", selected_rarity)


# ============================================
# START COIN ARC
# ============================================

func start_coin_arc() -> void:
	if player == null:
		return

	state = WellState.COIN_FLYING

	well_sprite.play("Idle")

	perk_coin_display.global_position = coin_spawn_position.global_position
	perk_coin_display.visible = true

	perk_coin.play(selected_perk)

	coin_arc_start = coin_spawn_position.global_position
	coin_arc_end = player.global_position + Vector2(0.0, -coin_hover_height)

	var middle: Vector2 = (coin_arc_start + coin_arc_end) * 0.5

	coin_arc_control = middle + Vector2(0.0, -coin_arc_height)
	coin_arc_progress = 0.0

	update_interaction_text()


# ============================================
# UPDATE COIN ARC
# ============================================

func update_coin_arc(delta: float) -> void:
	if coin_travel_time <= 0.0:
		finish_coin_arc()
		return

	coin_arc_progress += delta / coin_travel_time
	coin_arc_progress = minf(coin_arc_progress, 1.0)

	perk_coin_display.global_position = quadratic_bezier(
		coin_arc_start,
		coin_arc_control,
		coin_arc_end,
		coin_arc_progress
	)

	if coin_arc_progress >= 1.0:
		finish_coin_arc()


# ============================================
# QUADRATIC BEZIER
# ============================================

func quadratic_bezier(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	var first: Vector2 = start.lerp(control, t)
	var second: Vector2 = control.lerp(end, t)

	return first.lerp(second, t)


# ============================================
# FINISH COIN ARC
# ============================================

func finish_coin_arc() -> void:
	if player == null:
		return

	state = WellState.WAITING_FOR_CLICK

	coin_hover_position = player.global_position + Vector2(0.0, -coin_hover_height)
	perk_coin_display.global_position = coin_hover_position

	hover_time = 0.0

	face_player_forward()
	update_interaction_text()


# ============================================
# COIN HOVER
# ============================================

func update_coin_hover(delta: float) -> void:
	if player == null:
		return

	hover_time += delta * hover_speed

	var hover_offset: float = sin(hover_time) * hover_amount

	coin_hover_position = player.global_position + Vector2(0.0, -coin_hover_height)
	perk_coin_display.global_position = coin_hover_position + Vector2(0.0, hover_offset)


# ============================================
# OPEN PERK MENU
# ============================================

func open_perk_menu() -> void:
	if state != WellState.WAITING_FOR_CLICK:
		return

	state = WellState.PERK_MENU

	perk_coin_display.visible = false

	if interaction_box != null:
		interaction_box.hide_text()

	if perk_hud != null:
		perk_hud.open_perk_selection(selected_perk, selected_rarity)

	print("OPEN PERK MENU")
	print("Selected Perk: ", selected_perk)
	print("Rarity: ", selected_rarity)


# ============================================
# PERK SELECTION COMPLETED
# ============================================

func _on_perk_selection_completed() -> void:
	if state != WellState.PERK_MENU:
		return

	show_player_weapon()
	unlock_player()

	if wave_manager != null:
		wave_manager.resume_wave_countdown()

	state = WellState.INACTIVE

	selected_perk = ""
	selected_rarity = ""

	update_well_availability()
	update_interaction_text()
