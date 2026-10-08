extends CanvasLayer

# ============================================
# NODES
# ============================================

@onready var layout: Control = $Layout
@onready var background: Sprite2D = $Layout/Background
@onready var fade: ColorRect = $Fade

# ============================================
# SETTINGS
# ============================================

@export var continue_action: StringName = &"interact"
@export var fade_in_time: float = 1.5

# ============================================
# SIGNALS
# ============================================

signal keybinds_closed

# ============================================
# STATE
# ============================================

var can_close: bool = false

# ============================================
# READY
# ============================================

func _ready() -> void:
	layer = 100

	await get_tree().process_frame

	center_layout()
	get_viewport().size_changed.connect(center_layout)

	# Fade from black into the info screen.
	var tween: Tween = create_tween()
	tween.tween_property(fade, "color:a", 0.0, fade_in_time)

	await tween.finished

	can_close = true

# ============================================
# CENTER LAYOUT
# ============================================

func center_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	layout.position = (viewport_size - layout.size) / 2.0
	background.position = layout.size / 2.0

# ============================================
# INPUT
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if not can_close:
		return

	if event.is_action_pressed(continue_action):
		close_keybinds()
		get_viewport().set_input_as_handled()

# ============================================
# CLOSE
# ============================================

func close_keybinds() -> void:
	if not can_close:
		return

	can_close = false

	keybinds_closed.emit()
	queue_free()
