extends Control

# ============================================
# NODES
# ============================================

@onready var flash: ColorRect = $Flash
@onready var bolts: Array[TextureRect] = [$Bolt, $Bolt2]
@onready var thunder: AudioStreamPlayer = $Thunder
@onready var zombie_hand: AnimatedSprite2D = $ZombieHand
@onready var zombie_growl: AudioStreamPlayer = $ZombieGrowl
@onready var settings_panel: Panel = $SettingsPanel
@onready var ui_hover: AudioStreamPlayer = $UIHover
@onready var ui_click: AudioStreamPlayer = $UIClick

var starting: bool = false

# ============================================
# READY
# ============================================

func _ready() -> void:
	$Start/Start.pressed.connect(_on_start_pressed)
	$Start/Exit.pressed.connect(_on_quit_pressed)

	_schedule_strike()

	$Start/Setting.pressed.connect(settings_panel.open)

	# Size and center the zombie hand to the screen
	resized.connect(fit_animation)
	fit_animation()

	# ============================================
	# BUTTON SOUNDS
	# ============================================
	# The _play_hover / _play_click functions were
	# never connected to anything, which is why no
	# sound came out.

	for b: BaseButton in [$Start/Start, $Start/Setting, $Start/Exit]:
		b.mouse_entered.connect(_play_hover)
		b.pressed.connect(_play_click)


func fit_animation() -> void:
	ScreenFit.cover(zombie_hand, size)

# ============================================
# BUTTONS
# ============================================

# ============================================
# UI SOUND
# ============================================

func _play_hover() -> void:

	if ui_hover.stream != null:
		ui_hover.play()


func _play_click() -> void:

	if ui_click.stream != null:
		ui_click.play()


func _on_start_pressed() -> void:
	# Ignore repeat presses
	if starting:
		return

	# Stops lightning from firing over the fade
	starting = true

	$Start/Start.disabled = true
	$Start/Exit.disabled = true
	$Start/Setting.disabled = true

	zombie_hand.visible = true
	zombie_hand.frame = 0
	zombie_hand.play()
	zombie_growl.play()

	await zombie_hand.animation_finished

	# Fade menu music.
	var audio_tween: Tween = create_tween()
	audio_tween.tween_property($AudioStreamPlayer, "volume_db", -40.0, 1.0)

	# Persistent fade + scene change.
	SceneTransition.change_scene("res://Scenes/main.tscn")

func _on_quit_pressed() -> void:
	# Give the click sound time to be heard
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()

# ============================================
# LIGHTNING FUNCTIONS
# ============================================

func _schedule_strike() -> void:
	await get_tree().create_timer(randf_range(2.5, 7.0)).timeout

	_strike()
	_schedule_strike()

func _strike() -> void:
	if starting:
		return

	# Accessibility: skip the visual flash, but
	# keep the thunder so the mood survives
	if not GameOptions.lightning_enabled:
		await get_tree().create_timer(randf_range(0.4, 1.2)).timeout
		_play_thunder()
		return

	var active: Array = bolts if randf() < 0.2 else [bolts.pick_random()]

	for b in active:
		b.visible = true

	var t: Tween = create_tween()

	t.tween_property(flash, "color:a", 0.85, 0.04)
	t.tween_property(flash, "color:a", 0.05, 0.07)
	t.tween_property(flash, "color:a", 0.65, 0.05)

	t.tween_callback(func():
		for b in active:
			b.visible = false
	)

	t.tween_property(flash, "color:a", 0.0, 0.35)

	await get_tree().create_timer(randf_range(0.4, 1.2)).timeout
	_play_thunder()


func _play_thunder() -> void:
	thunder.pitch_scale = randf_range(0.8, 1.15)
	thunder.volume_db = randf_range(-8.0, 0.0)
	thunder.play()
