
extends Control

signal perk_selection_completed

# ============================================
# NODES
# ============================================

@onready var slots_container: HBoxContainer = $Slots
@onready var perk_title: Label = $PerkTitle
@onready var selection_arrow: AnimatedSprite2D = $SelectionArrow
@onready var replace_x: TextureRect = $ReplaceX

@onready var new_perk: Control = $NewPerk
@onready var new_perk_coin: TextureRect = $NewPerk/Coin
@onready var perk_name_label: Label = $NewPerk/PerkName
@onready var rarity_label: Label = $NewPerk/Rarity
@onready var description_label: Label = $NewPerk/Description

@onready var confirm_text: Label = $ConfirmText

# ============================================
# SLOT SETTINGS
# ============================================

@export_category("Slot Settings")

@export var perk_slot_scene: PackedScene
@export var blank_coin_texture: Texture2D
@export var discard_slot_texture: Texture2D
@export var starting_slots: int = 5

var max_perk_slots: int = 5
var perk_slots: Array[TextureRect] = []
var discard_slot: TextureRect = null

# ============================================
# MENU ANIMATION SETTINGS
# ============================================

@export_category("Menu Animation")

@export var menu_slots_position: Vector2 = Vector2(300.0, 120.0)
@export var menu_slots_scale: Vector2 = Vector2(1.5, 1.5)
@export var menu_animation_time: float = 0.35

var normal_slots_position: Vector2
var normal_slots_scale: Vector2

# ============================================
# PERK TEXTURES
# ============================================

@export_category("Perk Textures")

@export var ammo_texture: Texture2D
@export var health_texture: Texture2D
@export var damage_texture: Texture2D
@export var dash_texture: Texture2D

@export var reload_texture: Texture2D
@export var aim_texture: Texture2D
@export var firerate_texture: Texture2D

@export var bounce_texture: Texture2D
@export var bullet_texture: Texture2D
@export var pierce_texture: Texture2D

# ============================================
# STATE
# ============================================

var menu_open: bool = false
var current_new_perk: String = ""
var current_rarity: String = ""

# ============================================
# SELECTION STATE
# ============================================

var selected_slot_index: int = 0
var selection_enabled: bool = false

@export_category("Selection Settings")

@export var arrow_offset: Vector2 = Vector2(0.0, 25.0)
@export var new_coin_offset: Vector2 = Vector2(0.0, 125.0)
@export var replace_x_offset: Vector2 = Vector2.ZERO
@export var replace_x_scale: float = 1.25

# ============================================
# READY
# ============================================

func _ready() -> void:
	add_to_group("perk_hud")

	max_perk_slots = starting_slots

	normal_slots_position = slots_container.position
	normal_slots_scale = slots_container.scale

	setup_normal_hud()
	create_perk_slots()

# ============================================
# NORMAL HUD
# ============================================

func setup_normal_hud() -> void:
	perk_title.visible = false
	selection_arrow.visible = false
	replace_x.visible = false
	new_perk.visible = false
	confirm_text.visible = false

	visible = true

# ============================================
# CREATE PERK SLOTS
# ============================================

func create_perk_slots() -> void:
	for child: Node in slots_container.get_children():
		child.queue_free()

	perk_slots.clear()
	discard_slot = null

	for i: int in range(max_perk_slots):
		var slot: TextureRect = perk_slot_scene.instantiate() as TextureRect

		slots_container.add_child(slot)
		perk_slots.append(slot)

		if slot.has_method("setup"):
			slot.setup(i, blank_coin_texture)

# ============================================
# ADD PERK SLOT
# ============================================

func add_perk_slot(amount: int = 1) -> void:
	max_perk_slots += amount

	for i: int in range(amount):
		var slot_index: int = max_perk_slots - amount + i
		var slot: TextureRect = perk_slot_scene.instantiate() as TextureRect

		if discard_slot != null:
			slots_container.add_child(slot)
			slots_container.move_child(slot, discard_slot.get_index())
			perk_slots.insert(perk_slots.size() - 1, slot)
		else:
			slots_container.add_child(slot)
			perk_slots.append(slot)

		if slot.has_method("setup"):
			slot.setup(slot_index, blank_coin_texture)

# ============================================
# OPEN PERK SELECTION
# ============================================

func open_perk_selection(perk_name: String, rarity: String) -> void:
	if menu_open:
		return

	menu_open = true
	current_new_perk = perk_name
	current_rarity = rarity

	update_new_perk_display()

	perk_title.text = "YOUR COINS"
	perk_title.visible = true
	new_perk.visible = true

	selection_arrow.visible = false
	replace_x.visible = false

	confirm_text.text = "A / D to Select\nE to Confirm"
	confirm_text.visible = true

	selected_slot_index = 0
	selection_enabled = false

	create_discard_slot()
	animate_slots_to_menu()

# ============================================
# DISCARD SLOT
# ============================================

func create_discard_slot() -> void:
	if discard_slot != null:
		return

	discard_slot = perk_slot_scene.instantiate() as TextureRect

	if discard_slot == null:
		return

	slots_container.add_child(discard_slot)
	perk_slots.append(discard_slot)

	discard_slot.texture = discard_slot_texture

	if "slot_index" in discard_slot:
		discard_slot.slot_index = perk_slots.size() - 1

	if "perk_name" in discard_slot:
		discard_slot.perk_name = "DISCARD"

	if "is_empty" in discard_slot:
		discard_slot.is_empty = true

func remove_discard_slot() -> void:
	if discard_slot == null:
		return

	perk_slots.erase(discard_slot)
	discard_slot.queue_free()
	discard_slot = null

func is_discard_selected() -> bool:
	if discard_slot == null:
		return false

	if selected_slot_index < 0 or selected_slot_index >= perk_slots.size():
		return false

	return perk_slots[selected_slot_index] == discard_slot

# ============================================
# FIND STARTING SLOT
# ============================================

func find_starting_slot() -> int:
	for i: int in range(max_perk_slots):
		if i >= perk_slots.size():
			break

		if perk_slots[i].is_empty:
			return i

	return 0

# ============================================
# ANIMATE SLOTS TO MENU
# ============================================

func animate_slots_to_menu() -> void:
	await get_tree().process_frame

	var viewport_size: Vector2 = get_viewport_rect().size
	var scaled_width: float = slots_container.size.x * menu_slots_scale.x

	var target_position: Vector2 = Vector2(
		(viewport_size.x - scaled_width) * 0.5,
		menu_slots_position.y
	)

	var tween: Tween = create_tween()

	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(slots_container, "position", target_position, menu_animation_time)
	tween.tween_property(slots_container, "scale", menu_slots_scale, menu_animation_time)

	tween.chain().tween_callback(enable_slot_selection)

# ============================================
# UPDATE NEW PERK DISPLAY
# ============================================

func update_new_perk_display() -> void:
	new_perk_coin.texture = get_perk_texture(current_new_perk)
	perk_name_label.text = get_perk_display_name(current_new_perk)
	description_label.text = get_perk_description(current_new_perk)

	update_rarity_display()

# ============================================
# UPDATE RARITY DISPLAY
# ============================================

func update_rarity_display() -> void:
	match current_rarity.to_upper():
		"COMMON":
			rarity_label.text = "COMMON COIN"
			rarity_label.add_theme_color_override("font_color", Color("#3f6403"))

		"EPIC":
			rarity_label.text = "EPIC COIN"
			rarity_label.add_theme_color_override("font_color", Color("#744188"))

		"LEGENDARY":
			rarity_label.text = "LEGENDARY COIN"
			rarity_label.add_theme_color_override("font_color", Color("#bb043c"))

		_:
			rarity_label.text = "UNKNOWN COIN"
			rarity_label.add_theme_color_override("font_color", Color.WHITE)

# ============================================
# GET PERK TEXTURE
# ============================================

func get_perk_texture(perk_name: String) -> Texture2D:
	match perk_name:
		"Ammo_Coin":
			return ammo_texture
		"Health_Coin":
			return health_texture
		"Dmg_Coin":
			return damage_texture
		"Dash_Coin":
			return dash_texture
		"Reload_Coin":
			return reload_texture
		"Aim_Coin":
			return aim_texture
		"Firerate_Coin":
			return firerate_texture
		"Bounce_Coin":
			return bounce_texture
		"Bullet_Coin":
			return bullet_texture
		"Pierce_Coin":
			return pierce_texture

	return blank_coin_texture

# ============================================
# GET PERK DISPLAY NAME
# ============================================

func get_perk_display_name(perk_name: String) -> String:
	match perk_name:
		"Ammo_Coin":
			return "AMMO INCREASE"
		"Health_Coin":
			return "HEALTH INCREASE"
		"Dmg_Coin":
			return "DAMAGE INCREASE"
		"Dash_Coin":
			return "DASH RECHARGE"
		"Reload_Coin":
			return "RELOAD DECREASE"
		"Aim_Coin":
			return "ACCURACY INCREASE"
		"Firerate_Coin":
			return "FIRE RATE INCREASE"
		"Bounce_Coin":
			return "BOUNCE INCREASE"
		"Bullet_Coin":
			return "MULTI SHOT"
		"Pierce_Coin":
			return "PIERCE INCREASE"

	return "UNKNOWN PERK"

# ============================================
# GET PERK DESCRIPTION
# ============================================

func get_perk_description(perk_name: String) -> String:
	match perk_name:
		"Ammo_Coin":
			return "Increases your weapon's maximum ammo by 20%"
		"Health_Coin":
			return "Increases your maximum health by 20%"
		"Dmg_Coin":
			return "Increases your weapon damage by 20%"
		"Dash_Coin":
			return "Reduces your dash recharge time by 20%"
		"Reload_Coin":
			return "Reduces your weapon reload time by 20%"
		"Aim_Coin":
			return "Improves accuracy while aiming"
		"Firerate_Coin":
			return "Increases your weapon fire rate by 20%"
		"Bounce_Coin":
			return "Allows bullets to bounce +1"
		"Bullet_Coin":
			return "Adds +1 bullet to each shot"
		"Pierce_Coin":
			return "Allows bullets to pierce +1 enemy"

	return "No description available."

# ============================================
# ENABLE SLOT SELECTION
# ============================================

func enable_slot_selection() -> void:
	selected_slot_index = find_starting_slot()

	selection_enabled = true
	selection_arrow.visible = true
	selection_arrow.play()

	update_selection_visuals()

# ============================================
# SELECTION INPUT
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if not menu_open:
		return

	if not selection_enabled:
		return

	if event.is_action_pressed("ui_left") or is_key_pressed(event, KEY_A):
		change_selected_slot(-1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_right") or is_key_pressed(event, KEY_D):
		change_selected_slot(1)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") or is_key_pressed(event, KEY_E):
		confirm_selected_slot()
		get_viewport().set_input_as_handled()
		return

# ============================================
# KEY INPUT
# ============================================

func is_key_pressed(event: InputEvent, key: Key) -> bool:
	if event is not InputEventKey:
		return false

	var key_event: InputEventKey = event as InputEventKey

	return key_event.pressed and not key_event.echo and key_event.physical_keycode == key

# ============================================
# CHANGE SELECTED SLOT
# ============================================

func change_selected_slot(direction: int) -> void:
	if perk_slots.is_empty():
		return

	selected_slot_index += direction

	if selected_slot_index < 0:
		selected_slot_index = perk_slots.size() - 1

	if selected_slot_index >= perk_slots.size():
		selected_slot_index = 0

	update_selection_visuals()

# ============================================
# UPDATE SELECTION VISUALS
# ============================================

func update_selection_visuals() -> void:
	if perk_slots.is_empty():
		return

	if selected_slot_index < 0 or selected_slot_index >= perk_slots.size():
		return

	await get_tree().process_frame

	var selected_slot: TextureRect = perk_slots[selected_slot_index]
	var slot_global_rect: Rect2 = selected_slot.get_global_rect()
	var slot_center: Vector2 = slot_global_rect.position + slot_global_rect.size * 0.5

	position_arrow(slot_center)
	position_new_perk(slot_center)
	update_replace_x(selected_slot, slot_center)
	update_selection_text()

# ============================================
# POSITION ARROW
# ============================================

func position_arrow(slot_center: Vector2) -> void:
	var hud_inverse: Transform2D = get_global_transform().affine_inverse()
	var local_position: Vector2 = hud_inverse * slot_center

	selection_arrow.position = local_position + arrow_offset

# ============================================
# POSITION NEW PERK COIN
# ============================================

func position_new_perk(slot_center: Vector2) -> void:
	if selected_slot_index < 0 or selected_slot_index >= perk_slots.size():
		return

	var selected_slot: TextureRect = perk_slots[selected_slot_index]
	var slot_rect: Rect2 = selected_slot.get_global_rect()
	var coin_size: Vector2 = slot_rect.size
	var coin_local_center: Vector2 = new_perk.get_global_transform().affine_inverse() * slot_center

	new_perk_coin.size = coin_size

	new_perk_coin.position = Vector2(
		coin_local_center.x - coin_size.x * 0.5 + new_coin_offset.x,
		coin_local_center.y - coin_size.y * 0.5 + new_coin_offset.y
	)

# ============================================
# UPDATE REPLACE X
# ============================================

func update_replace_x(selected_slot: TextureRect, slot_center: Vector2) -> void:
	if is_discard_selected():
		replace_x.visible = false
		return

	if selected_slot.is_empty:
		replace_x.visible = false
		return

	replace_x.visible = true

	var slot_rect: Rect2 = selected_slot.get_global_rect()
	var x_size: Vector2 = slot_rect.size * replace_x_scale

	replace_x.size = x_size

	var hud_inverse: Transform2D = get_global_transform().affine_inverse()
	var local_position: Vector2 = hud_inverse * slot_center

	replace_x.position = local_position - x_size * 0.5 + replace_x_offset

# ============================================
# UPDATE SELECTION TEXT
# ============================================

func update_selection_text() -> void:
	if is_discard_selected():
		confirm_text.text = "A / D to Select\nE to Discard"
		return

	var selected_slot: TextureRect = perk_slots[selected_slot_index]

	if selected_slot.is_empty:
		confirm_text.text = "A / D to Select\nE to Equip"
	else:
		confirm_text.text = "A / D to Select\nE to Replace"

# ============================================
# CONFIRM SELECTED SLOT
# ============================================

func confirm_selected_slot() -> void:
	if selected_slot_index < 0 or selected_slot_index >= perk_slots.size():
		return

	selection_enabled = false

	if is_discard_selected():
		print("DISCARDED PERK: ", current_new_perk)
		discard_new_perk()
		return

	var selected_slot: TextureRect = perk_slots[selected_slot_index]

	print("PERK SELECTED: ", current_new_perk)
	print("SLOT: ", selected_slot_index + 1)

	place_perk_in_slot(selected_slot)

# ============================================
# PLACE PERK IN SLOT
# ============================================

func place_perk_in_slot(selected_slot: TextureRect) -> void:
	var perk_texture: Texture2D = get_perk_texture(current_new_perk)

	if selected_slot.has_method("set_perk"):
		selected_slot.set_perk(current_new_perk, perk_texture)

	apply_equipped_perks()
	finish_perk_selection()

# ============================================
# APPLY EQUIPPED PERKS
# ============================================

func apply_equipped_perks() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")

	if player == null:
		print("ERROR: PerkHUD could not find Player!")
		return

	var equipped: Array[String] = []

	for i: int in range(max_perk_slots):
		if i >= perk_slots.size():
			break

		var slot: TextureRect = perk_slots[i]

		if slot.is_empty:
			continue

		if slot.perk_name == "":
			continue

		equipped.append(slot.perk_name)

	if player.has_method("apply_perks"):
		player.apply_perks(equipped)

# ============================================
# DISCARD NEW PERK
# ============================================

func discard_new_perk() -> void:
	finish_perk_selection()

# ============================================
# FINISH PERK SELECTION
# ============================================

func finish_perk_selection() -> void:
	selection_enabled = false

	selection_arrow.visible = false
	replace_x.visible = false
	new_perk.visible = false
	perk_title.visible = false
	confirm_text.visible = false

	remove_discard_slot()

	await get_tree().process_frame

	var tween: Tween = create_tween()

	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(slots_container, "position", normal_slots_position, menu_animation_time)
	tween.tween_property(slots_container, "scale", normal_slots_scale, menu_animation_time)

	tween.chain().tween_callback(perk_selection_finished)

# ============================================
# SELECTION FINISHED
# ============================================

func perk_selection_finished() -> void:
	menu_open = false
	current_new_perk = ""
	current_rarity = ""
	selected_slot_index = 0

	perk_selection_completed.emit()
