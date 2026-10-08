extends Control


# ============================================
# NODES
# ============================================

@onready var helpful_text: Label = $HelpfulText


# ============================================
# SETTINGS
# ============================================

@export var slide_distance: float = 150.0
@export var slide_time: float = 0.25


# ============================================
# VARIABLES
# ============================================

var shown_position: Vector2
var hidden_position: Vector2
var current_tween: Tween = null


# ============================================
# READY
# ============================================

func _ready() -> void:
	add_to_group("interaction_box")

	shown_position = position
	hidden_position = shown_position + Vector2(0.0, slide_distance)

	position = hidden_position

	print("InteractionBox READY")
	print("Shown position: ", shown_position)
	print("Hidden position: ", hidden_position)


# ============================================
# SHOW TEXT
# ============================================

func show_text(new_text: String) -> void:
	print("SHOW TEXT CALLED: ", new_text)

	helpful_text.text = new_text
	visible = true

	if current_tween != null:
		current_tween.kill()

	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_QUAD)
	current_tween.set_ease(Tween.EASE_OUT)
	current_tween.tween_property(self, "position", shown_position, slide_time)


# ============================================
# HIDE TEXT
# ============================================

func hide_text() -> void:
	print("HIDE TEXT CALLED")

	if current_tween != null:
		current_tween.kill()

	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_QUAD)
	current_tween.set_ease(Tween.EASE_IN)
	current_tween.tween_property(self, "position", hidden_position, slide_time)
