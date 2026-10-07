extends Node2D

# ============================================
# NODES
# ============================================

@onready var keybinds = $Keybinds
@onready var wave_manager = $"Wave Manager"
@onready var hud: CanvasLayer = $HUD
@onready var player: CharacterBody2D = $YSortWorld/Player

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
# KEYBINDS CLOSED
# ============================================

func _on_keybinds_closed() -> void:
	# Show normal game HUD.
	hud.visible = true

	# Give control back to player.
	player.is_locked = false

	# Start Wave 1 countdown.
	wave_manager.start_game()
