class_name ScreenFade

# ============================================
# SCREEN FADE
# ============================================
# Fades the whole screen to black, then returns.
# Call it with await:
#
#   await ScreenFade.to_black(self, 2.0)
#   get_tree().change_scene_to_file("res://...")
#
# The fade layer is added as a child of the
# current scene, so it is freed automatically
# when the scene changes. Adding it to the root
# instead would leave a black rectangle stuck
# over the next scene.
# ============================================


static func to_black(from: Node, duration: float) -> void:

	if from == null:
		return

	var tree: SceneTree = from.get_tree()

	if tree == null or tree.current_scene == null:
		return

	var layer := CanvasLayer.new()

	# Above the HUD
	layer.layer = 100

	tree.current_scene.add_child(layer)

	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)

	# Anchors only apply once the node is in the tree
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	var t := from.create_tween()
	t.tween_property(rect, "color:a", 1.0, duration)

	await t.finished
