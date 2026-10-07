extends Control

# ============================================
# DEATH SCREEN
# ============================================
# Runs after the player dies and the gameplay
# scene has already faded to black.
#
# Order of events:
#   1. Zombie animation plays once
#   2. Lightning flashes on the final frame
#   3. Zombie yell plays
#   4. Main / Exit buttons fade in
# ============================================

@onready var death_anim: AnimatedSprite2D = $DeathAnim
@onready var flash: ColorRect = $Flash
@onready var zombie_yell: AudioStreamPlayer = $ZombieYell

@onready var buttons: Control = $Buttons
@onready var main_button: TextureButton = $Buttons/MainButton
@onready var exit_button: TextureButton = $Buttons/ExitButton

@onready var ui_hover: AudioStreamPlayer = $UIHover
@onready var ui_click: AudioStreamPlayer = $UIClick

# ============================================
# TIMING
# ============================================

# Delay between the flash starting and the yell.
# 0.0 lands the roar on the first flash frame,
# which is what makes it land as a jump scare.
const YELL_DELAY: float = 0.0

# Pause after the yell before the buttons appear
const BUTTON_DELAY: float = 1.0

# How long the buttons take to fade in
const BUTTON_FADE: float = 0.8

# Pause after a click so the sound is audible
const CLICK_PAUSE: float = 0.25

var leaving: bool = false


# ============================================
# READY
# ============================================

func _ready() -> void:

	# Start with no flash on screen
	flash.color = Color(1, 1, 1, 0)

	# Buttons stay hidden until the sequence ends
	buttons.visible = false
	buttons.modulate.a = 0.0

	# Size and center the animation to the screen.
	# Re-runs if the window changes size.
	resized.connect(fit_animation)
	fit_animation()

	# ============================================
	# BUTTON SIGNALS
	# ============================================

	main_button.pressed.connect(_on_main_pressed)
	exit_button.pressed.connect(_on_exit_pressed)

	main_button.mouse_entered.connect(_play_hover)
	exit_button.mouse_entered.connect(_play_hover)

	death_anim.frame = 0
	death_anim.play()

	# Wait for the animation to reach its last frame.
	# Loop must be OFF in the SpriteFrames resource
	# or this never fires.
	await death_anim.animation_finished

	_lightning()


# ============================================
# FIT ANIMATION TO SCREEN
# ============================================

func fit_animation() -> void:

	ScreenFit.cover(death_anim, size)

	# Keep the buttons locked to the artwork.
	# Their offsets are written in frame pixels
	# relative to the center of a 1152x648 frame,
	# so they track the head at any window size.
	buttons.position = (
		death_anim.position + death_anim.offset * death_anim.scale.x
	)
	buttons.scale = death_anim.scale


# ============================================
# LIGHTNING + YELL
# ============================================

func _lightning() -> void:

	# Accessibility: skip the strobe entirely,
	# but still play the yell on cue
	if not GameOptions.lightning_enabled:
		await get_tree().create_timer(YELL_DELAY).timeout
		if zombie_yell.stream != null:
			zombie_yell.play()
		await get_tree().create_timer(BUTTON_DELAY).timeout
		_show_buttons()
		return

	# Double strobe - real lightning does not fade
	# smoothly, it stutters
	var t := create_tween()
	t.tween_property(flash, "color:a", 0.9, 0.03)
	t.tween_property(flash, "color:a", 0.1, 0.06)
	t.tween_property(flash, "color:a", 0.85, 0.04)
	t.tween_property(flash, "color:a", 0.0, 0.5)

	# Yell lands on the second strobe
	await get_tree().create_timer(YELL_DELAY).timeout

	if zombie_yell.stream != null:
		zombie_yell.play()

	await t.finished
	await get_tree().create_timer(BUTTON_DELAY).timeout

	_show_buttons()


# ============================================
# SHOW BUTTONS
# ============================================

func _show_buttons() -> void:

	buttons.visible = true

	var t := create_tween()
	t.tween_property(buttons, "modulate:a", 1.0, BUTTON_FADE)


# ============================================
# UI SOUND
# ============================================

func _play_hover() -> void:

	if ui_hover.stream != null:
		ui_hover.play()


func _play_click() -> void:

	if ui_click.stream != null:
		ui_click.play()


# ============================================
# BUTTONS
# ============================================

func _on_main_pressed() -> void:

	if leaving:
		return

	leaving = true
	_disable_buttons()
	_play_click()

	await get_tree().create_timer(CLICK_PAUSE).timeout

	get_tree().change_scene_to_file("res://Scenes/start_screen.tscn")


func _on_exit_pressed() -> void:

	if leaving:
		return

	leaving = true
	_disable_buttons()
	_play_click()

	await get_tree().create_timer(CLICK_PAUSE).timeout

	get_tree().quit()


func _disable_buttons() -> void:

	main_button.disabled = true
	exit_button.disabled = true
