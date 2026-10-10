extends Panel

# ============================================
# SETTINGS PANEL
# ============================================
# One panel used by both the start screen and
# the pause menu. Which extras it shows is set
# per instance in the Inspector.
#
# Volumes live in the GameOptions autoload, so
# this script only drives the controls and
# reports when it closes.
# ============================================

@export var show_lightning_toggle: bool = true
@export var show_main_menu_button: bool = false

## Pauses the SceneTree while open. Use for the
## in-game pause menu, not the start screen.
@export var pauses_game: bool = false

signal closed
signal main_menu_requested

@onready var volume_slider: HSlider = $VBoxContainer/VolumeSlider
@onready var music_slider: HSlider = $VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SFXSlider
@onready var ui_slider: HSlider = $VBoxContainer/UISlider
@onready var lightning_check: CheckBox = $VBoxContainer/LightningCheck
@onready var main_menu_button: Button = $VBoxContainer/MainMenu
@onready var back_button: Button = $VBoxContainer/Backbutton

@onready var ui_hover: AudioStreamPlayer = $UIHover
@onready var ui_click: AudioStreamPlayer = $UIClick


# ============================================
# READY
# ============================================

func _ready() -> void:

	# ALWAYS, not WHEN_PAUSED: it has to run while
	# the game is running (to catch Escape and
	# open) AND while paused (so its own buttons
	# still work and can unpause).
	process_mode = Node.PROCESS_MODE_ALWAYS if pauses_game \
		else Node.PROCESS_MODE_INHERIT

	lightning_check.visible = show_lightning_toggle
	main_menu_button.visible = show_main_menu_button

	hide()

	_load_values()
	_connect_controls()


# ============================================
# LOAD SAVED VALUES
# ============================================

func _load_values() -> void:

	# set_value_no_signal avoids firing
	# value_changed before we are connected
	volume_slider.set_value_no_signal(GameOptions.master_volume)
	music_slider.set_value_no_signal(GameOptions.music_volume)
	sfx_slider.set_value_no_signal(GameOptions.sfx_volume)
	ui_slider.set_value_no_signal(GameOptions.ui_volume)

	lightning_check.set_pressed_no_signal(GameOptions.lightning_enabled)


# ============================================
# WIRE UP CONTROLS
# ============================================

func _connect_controls() -> void:

	volume_slider.value_changed.connect(
		func(v: float): GameOptions.set_volume(GameOptions.BUS_MASTER, v))
	music_slider.value_changed.connect(
		func(v: float): GameOptions.set_volume(GameOptions.BUS_MUSIC, v))
	sfx_slider.value_changed.connect(
		func(v: float): GameOptions.set_volume(GameOptions.BUS_SFX, v))

	# Clicks on this one so the player can hear
	# what they are setting
	ui_slider.value_changed.connect(_on_ui_volume_changed)

	lightning_check.toggled.connect(GameOptions.set_lightning_enabled)

	back_button.pressed.connect(close)
	main_menu_button.pressed.connect(_on_main_menu_pressed)

	for b: BaseButton in [back_button, main_menu_button]:
		b.mouse_entered.connect(_play_hover)
		b.pressed.connect(_play_click)


func _on_ui_volume_changed(value: float) -> void:
	GameOptions.set_volume(GameOptions.BUS_UI, value)
	_play_click()


# ============================================
# ESCAPE KEY
# ============================================
# Handled here rather than on the Main node,
# because Main stops processing when the tree
# pauses - Escape would open the menu but never
# close it again.
# ============================================

func _input(event: InputEvent) -> void:

	if not pauses_game:
		return

	if not event.is_action_pressed("ui_cancel"):
		return

	toggle()

	get_viewport().set_input_as_handled()


# ============================================
# OPEN / CLOSE
# ============================================

func open() -> void:

	if visible:
		return

	_load_values()
	show()

	if pauses_game:
		get_tree().paused = true


func close() -> void:

	if not visible:
		return

	hide()

	if pauses_game:
		get_tree().paused = false

	GameOptions.save_settings()

	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


# ============================================
# MAIN MENU
# ============================================

func _on_main_menu_pressed() -> void:

	# Unpause first - the new scene would be
	# frozen on arrival otherwise
	if pauses_game:
		get_tree().paused = false

	GameOptions.save_settings()

	main_menu_requested.emit()


# ============================================
# UI SOUND
# ============================================

func _play_hover() -> void:
	if ui_hover != null and ui_hover.stream != null:
		ui_hover.play()


func _play_click() -> void:
	if ui_click != null and ui_click.stream != null:
		ui_click.play()
