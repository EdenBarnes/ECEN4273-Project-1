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
@onready var volume_slider: HSlider = $SettingsPanel/VBoxContainer/VolumeSlider
@onready var music_slider: HSlider = $SettingsPanel/VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $SettingsPanel/VBoxContainer/SFXSlider
@onready var ui_slider: HSlider = $SettingsPanel/VBoxContainer/UISlider
@onready var lightning_check: CheckBox = $SettingsPanel/VBoxContainer/LightningCheck
@onready var backbutton: Button = $SettingsPanel/VBoxContainer/Backbutton
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

	$Start/Setting.pressed.connect(func(): settings_panel.visible = true)
	$SettingsPanel/VBoxContainer/Backbutton.pressed.connect(_close_settings)
	_setup_settings_controls()

	# Size and center the zombie hand to the screen
	resized.connect(fit_animation)
	fit_animation()

	# ============================================
	# BUTTON SOUNDS
	# ============================================
	# The _play_hover / _play_click functions were
	# never connected to anything, which is why no
	# sound came out.

	for b: BaseButton in [$Start/Start, $Start/Setting, $Start/Exit, backbutton]:
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

#-------------------------------------------------
#                 SETTINGS
#-------------------------------------------------
# All values live in the GameOptions autoload so
# every scene shares them and they survive a
# restart. Each slider drives one audio bus.
#-------------------------------------------------

func _setup_settings_controls() -> void:

	# Start each control at the saved value.
	# set_value_no_signal avoids firing
	# value_changed before we are connected.
	volume_slider.set_value_no_signal(GameOptions.master_volume)
	music_slider.set_value_no_signal(GameOptions.music_volume)
	sfx_slider.set_value_no_signal(GameOptions.sfx_volume)
	ui_slider.set_value_no_signal(GameOptions.ui_volume)

	lightning_check.set_pressed_no_signal(GameOptions.lightning_enabled)

	volume_slider.value_changed.connect(
		func(v: float): GameOptions.set_volume(GameOptions.BUS_MASTER, v))
	music_slider.value_changed.connect(
		func(v: float): GameOptions.set_volume(GameOptions.BUS_MUSIC, v))
	sfx_slider.value_changed.connect(
		func(v: float): GameOptions.set_volume(GameOptions.BUS_SFX, v))

	# Play a click when the menu volume moves so
	# the player can hear what they are setting
	ui_slider.value_changed.connect(_on_ui_volume_changed)

	lightning_check.toggled.connect(_on_lightning_toggled)


func _on_ui_volume_changed(value: float) -> void:
	GameOptions.set_volume(GameOptions.BUS_UI, value)
	_play_click()


func _on_lightning_toggled(enabled: bool) -> void:
	GameOptions.set_lightning_enabled(enabled)

	# Clear any flash still on screen
	if not enabled:
		flash.color.a = 0.0
		for b in bolts:
			b.visible = false


func _close_settings() -> void:
	settings_panel.visible = false
	GameOptions.save_settings()
