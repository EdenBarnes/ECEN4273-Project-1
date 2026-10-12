extends Area2D


# ============================================
# SIGNALS
# ============================================

signal coin_clicked


# ============================================
# INPUT
# ============================================

func _input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton

	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		coin_clicked.emit()
