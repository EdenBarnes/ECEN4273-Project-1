
extends CanvasLayer

# ============================================
# SETTINGS
# ============================================

@export var fade_time: float = 1.0

# ============================================
# NODES
# ============================================

var fade: ColorRect

# ============================================
# READY
# ============================================

func _ready() -> void:
	layer = 1000

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	add_child(fade)

# ============================================
# CHANGE SCENE
# ============================================

func change_scene(scene_path: String) -> void:
	# Fade current scene to black.
	var fade_out: Tween = create_tween()
	fade_out.tween_property(fade, "color:a", 1.0, fade_time)
	await fade_out.finished

	# Change scene while black overlay remains.
	get_tree().change_scene_to_file(scene_path)

	# Give new scene time to load/render.
	await get_tree().process_frame
	await get_tree().process_frame

	# Fade black away.
	var fade_in: Tween = create_tween()
	fade_in.tween_property(fade, "color:a", 0.0, fade_time)
	await fade_in.finished
