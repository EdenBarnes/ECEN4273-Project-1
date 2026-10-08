extends Node2D

# ============================================
# NODES
# ============================================

@onready var keybinds = $Keybinds
@onready var wave_manager = $"Wave Manager"
@onready var hud: CanvasLayer = $HUD
@onready var player = $YSortWorld/Player

# ============================================
# READY
# ============================================

func _ready() -> void:
	hud.visible = false

	player.is_locked = true
	player.velocity = Vector2.ZERO
	player.weapon_holder.visible = false

	keybinds.keybinds_closed.connect(_on_keybinds_closed)

# ============================================
# KEYBINDS CLOSED
# ============================================

func _on_keybinds_closed() -> void:
	hud.visible = true

	player.weapon_holder.visible = true
	player.is_locked = false

	wave_manager.start_game()
