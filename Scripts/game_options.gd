extends Node

# ============================================
# GAME OPTIONS
# ============================================
# Autoload singleton. Owns everything the player
# can change in the Settings menu, applies it to
# the engine, and saves it to disk so it survives
# a restart.
#
# Volumes map onto the audio buses defined in
# default_bus_layout.tres:
#
#   Master
#     |- Music    theme music
#     |- SFX      thunder, guns, zombies, coins
#     |- UI       button hover and click
#
# Anything that plays a sound just needs its
# AudioStreamPlayer "Bus" set to the right one
# in the Inspector. No script changes needed.
# ============================================

const CONFIG_PATH: String = "user://settings.cfg"

const BUS_MASTER: String = "Master"
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const BUS_UI: String = "UI"

# ============================================
# VOLUMES (0.0 - 1.0)
# ============================================

var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var ui_volume: float = 1.0

# ============================================
# ACCESSIBILITY
# ============================================
# Turning this off removes the full screen
# lightning flashes for players sensitive to
# flashing images. Thunder still plays.

var lightning_enabled: bool = true

signal lightning_setting_changed(enabled: bool)


# ============================================
# READY
# ============================================

func _ready() -> void:
	load_settings()
	apply_all()


# ============================================
# VOLUME
# ============================================

func set_volume(bus_name: String, value: float) -> void:

	value = clampf(value, 0.0, 1.0)

	match bus_name:
		BUS_MUSIC:
			music_volume = value
		BUS_SFX:
			sfx_volume = value
		BUS_UI:
			ui_volume = value
		_:
			master_volume = value

	apply_bus(bus_name, value)


func get_volume(bus_name: String) -> float:

	match bus_name:
		BUS_MUSIC:
			return music_volume
		BUS_SFX:
			return sfx_volume
		BUS_UI:
			return ui_volume
		_:
			return master_volume


# ============================================
# APPLY TO AUDIO SERVER
# ============================================

func apply_bus(bus_name: String, value: float) -> void:

	var idx: int = AudioServer.get_bus_index(bus_name)

	if idx < 0:
		push_warning("Audio bus not found: " + bus_name)
		return

	# Sliders move 0-1 linearly, which matches how
	# volume is heard. The audio server wants
	# decibels, so convert.
	AudioServer.set_bus_volume_db(idx, linear_to_db(value))

	# 0.0 linear converts to -inf db, so mute instead
	AudioServer.set_bus_mute(idx, value < 0.01)


func apply_all() -> void:
	apply_bus(BUS_MASTER, master_volume)
	apply_bus(BUS_MUSIC, music_volume)
	apply_bus(BUS_SFX, sfx_volume)
	apply_bus(BUS_UI, ui_volume)


# ============================================
# LIGHTNING TOGGLE
# ============================================

func set_lightning_enabled(enabled: bool) -> void:
	lightning_enabled = enabled
	lightning_setting_changed.emit(enabled)


# ============================================
# SAVE / LOAD
# ============================================

func save_settings() -> void:

	var cfg := ConfigFile.new()

	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "ui", ui_volume)

	cfg.set_value("accessibility", "lightning", lightning_enabled)

	cfg.save(CONFIG_PATH)


func load_settings() -> void:

	var cfg := ConfigFile.new()

	if cfg.load(CONFIG_PATH) != OK:
		return

	master_volume = cfg.get_value("audio", "master", 1.0)
	music_volume = cfg.get_value("audio", "music", 1.0)
	sfx_volume = cfg.get_value("audio", "sfx", 1.0)
	ui_volume = cfg.get_value("audio", "ui", 1.0)

	lightning_enabled = cfg.get_value("accessibility", "lightning", true)
