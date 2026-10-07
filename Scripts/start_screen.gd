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
@onready var backbutton: Button = $SettingsPanel/VBoxContainer/Backbutton

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

	volume_slider.value_changed.connect(_on_volume_changed)
	volume_slider.value = _load_volume()

# ============================================
# BUTTONS
# ============================================

func _on_start_pressed() -> void:
	if starting:
		return

	starting = true

	$Start/Start.disabled = true
	$Start/Exit.disabled = true

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

	thunder.pitch_scale = randf_range(0.8, 1.15)
	thunder.volume_db = randf_range(-8.0, 0.0)
	thunder.play()

# ============================================
# SETTINGS FUNCTIONS - VOLUME
# ============================================

func _on_volume_changed(value: float) -> void:
	var bus: int = AudioServer.get_bus_index("Master")

	AudioServer.set_bus_volume_db(bus, linear_to_db(value))
	AudioServer.set_bus_mute(bus, value < 0.01)

func _close_settings() -> void:
	settings_panel.visible = false
	_save_volume(volume_slider.value)

func _save_volume(value: float) -> void:
	var cfg: ConfigFile = ConfigFile.new()

	cfg.set_value("audio", "master", value)
	cfg.save("user://settings.cfg")

func _load_volume() -> float:
	var cfg: ConfigFile = ConfigFile.new()

	if cfg.load("user://settings.cfg") == OK:
		return cfg.get_value("audio", "master", 1.0)

	return 1.0
