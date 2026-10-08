extends Control

# ============================================
# NODES
# ============================================

@onready var titlecard: AnimatedSprite2D = $Titlecard
@onready var blood_trickling: AudioStreamPlayer = $"Blood Trickling"

# ============================================
# STATE
# ============================================

var leaving: bool = false

# ============================================
# READY
# ============================================

func _ready() -> void:
	# Size and center the titlecard to the screen
	resized.connect(fit_animation)
	fit_animation()

	titlecard.play()
	blood_trickling.play()

	await titlecard.animation_finished

	# Fade the trickle out instead of cutting it
	# dead, which pops. Runs during the hold
	# below, so it costs no extra time.
	var t: Tween = create_tween()
	t.tween_property(blood_trickling, "volume_db", -40.0, 0.5)

	await get_tree().create_timer(1.0).timeout

	_leave()

# ============================================
# FIT TITLE CARD
# ============================================

func fit_animation() -> void:
	ScreenFit.cover(titlecard, size)

# ============================================
# SKIP INTRO
# ============================================

func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") \
	or (event is InputEventMouseButton and event.pressed):
		_leave()

# ============================================
# LEAVE INTRO
# ============================================

func _leave() -> void:
	if leaving:
		return

	leaving = true

	# Persistent fade + scene change.
	SceneTransition.change_scene("res://Scenes/start_screen.tscn")
