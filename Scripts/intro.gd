extends Control

# ============================================
# NODES
# ============================================

@onready var titlecard: AnimatedSprite2D = $Titlecard

# ============================================
# STATE
# ============================================

var leaving: bool = false

# ============================================
# READY
# ============================================

func _ready() -> void:
	await get_tree().process_frame

	center_titlecard()
	get_viewport().size_changed.connect(center_titlecard)

	titlecard.play()

	await titlecard.animation_finished
	await get_tree().create_timer(1.0).timeout

	_leave()

# ============================================
# CENTER TITLE CARD
# ============================================

func center_titlecard() -> void:
	var viewport_center: Vector2 = get_viewport_rect().size / 2.0
	titlecard.global_position = viewport_center

# ============================================
# SKIP INTRO
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
		_leave()

# ============================================
# LEAVE INTRO
# ============================================

func _leave() -> void:
	if leaving:
		return

	leaving = true

	SceneTransition.change_scene("res://Scenes/start_screen.tscn")
