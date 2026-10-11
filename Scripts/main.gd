extends Node2D

# ============================================
# NODES
# ============================================

@onready var keybinds = $Keybinds
@onready var wave_manager = $"Wave Manager"
@onready var hud: CanvasLayer = $HUD
@onready var player: CharacterBody2D = $YSortWorld/Player
@onready var settings_panel: Panel = $PauseLayer/SettingsPanel
@onready var settings_button: TextureButton = $HUD/HUDRoot/Setting
@onready var main_music: AudioStreamPlayer = $MainMusic

# ============================================
# MUSIC LOOP
# ============================================
# The track fades out over its last few seconds,
# pauses, then fades back in from the top.
#
# Import Loop is deliberately left OFF: a looping
# stream never emits finished and never ends, so
# there would be nothing to fade.
# ============================================

## Seconds of fade at each end
const MUSIC_FADE: float = 4.0

## Silence between the fade out and the restart
const MUSIC_GAP: float = 1.5

## Volume the fades drop to
const MUSIC_SILENT_DB: float = -40.0

var music_base_db: float = 0.0
var music_fading: bool = false

# ============================================
# READY
# ============================================

func _ready() -> void:
	# Hide normal game HUD during Keybind screen.
	hud.visible = false

	# Prevent player movement/actions.
	player.is_locked = true
	player.velocity = Vector2.ZERO

	# Wait for the Keybind screen to close.
	keybinds.keybinds_closed.connect(_on_keybinds_closed)

	# ============================================
	# PAUSE MENU
	# ============================================

	settings_button.pressed.connect(settings_panel.open)
	settings_panel.main_menu_requested.connect(_on_main_menu_requested)

	# Only this button needs to survive the pause.
	# Setting it on the whole HUD would keep every
	# HUD animation running too.
	settings_button.process_mode = Node.PROCESS_MODE_ALWAYS

	# No pausing until the Keybind screen is done
	settings_panel.set_process_input(false)

	# ============================================
	# MUSIC
	# ============================================

	music_base_db = main_music.volume_db
	main_music.finished.connect(_on_music_finished)


# ============================================
# MUSIC FADE OUT
# ============================================

func _process(_delta: float) -> void:

	if music_fading or not main_music.playing:
		return

	if main_music.stream == null:
		return

	var remaining: float = (
		main_music.stream.get_length() - main_music.get_playback_position()
	)

	if remaining > MUSIC_FADE:
		return

	music_fading = true

	# Fade over whatever is actually left, so it
	# reaches silence exactly as the track ends
	var t := create_tween()
	t.tween_property(
		main_music, "volume_db", MUSIC_SILENT_DB, maxf(remaining, 0.1)
	)


# ============================================
# MUSIC RESTART
# ============================================

func _on_music_finished() -> void:

	await get_tree().create_timer(MUSIC_GAP).timeout

	main_music.volume_db = MUSIC_SILENT_DB
	main_music.play()

	var t := create_tween()
	t.tween_property(main_music, "volume_db", music_base_db, MUSIC_FADE)
	await t.finished

	music_fading = false


# ============================================
# MAIN MENU
# ============================================

func _on_main_menu_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/start_screen.tscn")

# ============================================
# KEYBINDS CLOSED
# ============================================

func _on_keybinds_closed() -> void:
	# Show normal game HUD.
	hud.visible = true

	# Give control back to player.
	player.is_locked = false

	# Escape may now open the pause menu.
	settings_panel.set_process_input(true)

	# Start Wave 1 countdown.
	wave_manager.start_game()
