extends Node2D

# ============================================
# NODES
# ============================================

@onready var keybinds = $Keybinds
@onready var wave_manager = $"Wave Manager"
@onready var hud: CanvasLayer = $HUD
@onready var player: CharacterBody2D = $YSortWorld/Player
@onready var settings_panel: Panel = $PauseLayer/SettingsPanel
@onready var settings_button: TextureButton = $HUD/HUDRoot/Setting

# ============================================
# READY
# ============================================

func _ready() -> void:
	# Hide normal game HUD during Keybind screen.
	hud.visible = false

	# Prevent player movement/actions.
	player.is_locked = true
	player.velocity = Vector2.ZERO

	# Wait for the Keybind screen to close.
	keybinds.keybinds_closed.connect(_on_keybinds_closed)

	# ============================================
	# PAUSE MENU
	# ============================================

	settings_button.pressed.connect(settings_panel.open)
	settings_panel.main_menu_requested.connect(_on_main_menu_requested)

	# Only this button needs to survive the pause.
	# Setting it on the whole HUD would keep every
	# HUD animation running too.
	settings_button.process_mode = Node.PROCESS_MODE_ALWAYS

	# No pausing until the Keybind screen is done
	settings_panel.set_process_input(false)


# ============================================
# MAIN MENU
# ============================================

func _on_main_menu_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/start_screen.tscn")

# ============================================
# KEYBINDS CLOSED
# ============================================

func _on_keybinds_closed() -> void:
	# Show normal game HUD.
	hud.visible = true

	# Give control back to player.
	player.is_locked = false

	# Escape may now open the pause menu.
	settings_panel.set_process_input(true)

	# Start Wave 1 countdown.
	wave_manager.start_game()
