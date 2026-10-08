class_name ScreenFit

# ============================================
# SCREEN FIT
# ============================================
# Helper for full-canvas AnimatedSprite2D art
# (the intro titlecard, the zombie hand, the
# death animation).
#
# Those frames are drawn at the full 1152x648
# canvas size, so they need to cover the screen
# rather than sit at a fixed point. Hard coding
# position to Vector2(576, 324) only looks right
# on a window that happens to be exactly 16:9 -
# on anything else the art ends up off center.
#
# Pass the root Control's own `size`, not
# get_viewport_rect(). The Control is anchored
# Full Rect, so its size is always the real
# drawable area, and the sprite is its child in
# that same coordinate space.
# ============================================


static func cover(anim: AnimatedSprite2D, area: Vector2) -> void:

	if anim == null or anim.sprite_frames == null:
		return

	if area.x <= 0.0 or area.y <= 0.0:
		return

	var tex: Texture2D = anim.sprite_frames.get_frame_texture(
		anim.animation, 0
	)

	if tex == null:
		return

	var frame_size: Vector2 = tex.get_size()

	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return

	# Scale up until BOTH sides are covered.
	# Use minf() instead to letterbox rather than crop.
	var s: float = maxf(
		area.x / frame_size.x,
		area.y / frame_size.y
	)

	anim.scale = Vector2(s, s)
	anim.position = area / 2.0
