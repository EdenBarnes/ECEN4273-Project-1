extends Control

# ============================================
# WIN SCREEN
# ============================================
# Runs after the last wave is cleared and the
# gameplay scene has already faded to black.
#
# Order of events:
#   1. Win animation plays once
#	2. Title animation plays
#   3. Main / Exit buttons fade in
#
# If no SpriteFrames are assigned to
# WinAnimation yet, the animation step is
# skipped and the buttons appear on their own
# ============================================
@onready var fade_1: ColorRect = $Fade1
@onready var fade_2: ColorRect = $Fade2

@onready var win_anim: AnimatedSprite2D = $WinAnimation
@onready var titlecard: AnimatedSprite2D = $Titlecard

@onready var buttons: Control = $Buttons
@onready var main_button: TextureButton = $Buttons/MainButton
@onready var exit_button: TextureButton = $Buttons/ExitButton

@onready var ui_hover: AudioStreamPlayer = $UIHover
@onready var ui_click: AudioStreamPlayer = $UIClick
@onready var blood_trickling: AudioStreamPlayer = $"Blood Trickling"

@onready var credits: Control = $Credits
@onready var credits_text: RichTextLabel = $Credits/CreditsText


# ============================================
# CREDITS
# ============================================
# Edit the text below. [b]bold[/b] works, and a
# blank line is a blank line.
#
# TODO: replace the placeholder names with your
# team. Everything else is filled in.
# ============================================

const CREDITS_BODY: String = """[center][b]Z-RUSH[/b]

A game by

Dax Price
Alex Allen
Alex Jackson
Eden Barnes

[b]PROGRAMMING[/b]

Dax Price
Alex Allen
Alex Jackson
Eden Barnes


[b]ART AND ANIMATION[/b]

Dax Price
Alex Allen
Alex Jackson
Eden Barnes

Damage numbers font
https://silver500.itch.io/tiny56

Normal Game Font
https://www.dafont.com/vcr-osd-mono.font?text=0123456789

Keyboard layout screen
https://vryell.itch.io/controller-keyboard-icons

Boss health bar
https://bdragon1727.itch.io/basic-pixel-health-bar-and-scroll-bar

Guy and Zombie assets
https://snoblin.itch.io/pixel-rpg-free-npc/devlog/1641685/-added-dialog-portraits

[b]SOUND[/b]

Gun sounds from "Free Guns Sounds"
by moneywithjjcom
moneywithjjcom.itch.io/free-guns-sounds
Royalty-free, no attribution required

[b]From Freesound[/b]

"zombie noise2" by iSaria
freesound.org/s/326262
Attribution 4.0

"Heart collect/Healing (Retro)"
by ReincarnatedEchoes
freesound.org/s/644306
Attribution 4.0

"Footsteps On Dirt (Retro Style)"
by SilverIllusionist
freesound.org/s/672065
Attribution 4.0

"Fire Whoosh Samples" by mikiko850
freesound.org/s/848728
Attribution 4.0

"Wheel Spin sound" by roulettevision
freesound.org/s/420891
Attribution 3.0

"ARP Slot Machine Minor" by Johnnie_Holiday
freesound.org/s/587380
Creative Commons 0

"cyberpunk_metal" by Bertsz
freesound.org/s/672783
Creative Commons 0

"210104_0015 bicycle chain" by clothespeg
freesound.org/s/614037
Creative Commons 0

"click" by 1bob
freesound.org/s/717366
Creative Commons 0

"soft button click 7" by FOSSarts
freesound.org/s/750593
Creative Commons 0

[TODO - 9 sounds still need their Freesound IDs:
thunder, zombie growl, both theme tracks, blood
trickle, siren, coin, grunts, heartbeat]


[b]BUILT WITH[/b]

Godot Engine 4
Aseprite


[b]THANKS FOR PLAYING[/b][/center]"""

# Seconds for the whole roll, top to bottom
const CREDITS_SCROLL_TIME: float = 26.0

# ============================================
# TIMING
# ============================================

# Pause after the animation before the buttons
const BUTTON_DELAY: float = 1.0

# How long the buttons take to fade in
const BUTTON_FADE: float = 0.8

# Pause after a click so the sound is audible
const CLICK_PAUSE: float = 0.25

var leaving: bool = false
var credits_rolling: bool = false
var credits_tween: Tween = null


# ============================================
# READY
# ============================================

func _ready() -> void:

	# Buttons stay hidden until the animation ends
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

	# ============================================
	# PLAY THE ANIMATION
	# ============================================

	# ============================================
	# SEQUENCE
	# ============================================
	# win animation -> titlecard -> credits -> buttons

	# Skipped if no art is assigned yet
	if win_anim.sprite_frames != null:
		win_anim.frame = 0
		win_anim.play()

		# Loop must be OFF in the SpriteFrames
		# resource or this never fires.
		await win_anim.animation_finished
		
	var t := create_tween()
	t.tween_property(fade_1, "color:a", 1.0, 0.3)
	await t.finished
	
	titlecard.show()

	if titlecard.sprite_frames != null:
		titlecard.frame = 0
		titlecard.play()
		blood_trickling.play()
		await titlecard.animation_finished
	
	var t3 := create_tween()
	t3.tween_property(blood_trickling, "volume_db", -40.0, 0.5)
	
	var t2 := create_tween()
	t2.tween_property(fade_2, "color:a", 1.0, 0.5)
	await t2.finished

	await _roll_credits()

	await get_tree().create_timer(BUTTON_DELAY).timeout

	_show_buttons()


# ============================================
# CREDITS ROLL
# ============================================
# Scrolls from just below the screen to just
# above it. Any key or click skips to the end.
# ============================================

func _roll_credits() -> void:

	credits_text.text = CREDITS_BODY

	# Let the label work out how tall it is now
	# that it has content
	await get_tree().process_frame

	var text_height: float = credits_text.get_content_height()

	credits_text.position.y = size.y
	credits.modulate.a = 1.0
	credits.visible = true

	credits_rolling = true

	credits_tween = create_tween()
	credits_tween.set_trans(Tween.TRANS_LINEAR)
	credits_tween.tween_property(
		credits_text, "position:y", -text_height, CREDITS_SCROLL_TIME
	)

	# Resolves early if the player skips
	await credits_tween.finished

	credits_tween = null

	credits_rolling = false

	var fade_out := create_tween()
	fade_out.tween_property(credits, "modulate:a", 0.0, 0.5)
	await fade_out.finished

	credits.visible = false


# ============================================
# SKIP
# ============================================

func _unhandled_input(event: InputEvent) -> void:

	if not credits_rolling:
		return

	var pressed: bool = (
		event is InputEventKey and event.pressed and not event.echo
	) or (
		event is InputEventMouseButton and event.pressed
	)

	if not pressed:
		return

	credits_rolling = false

	# Jump the tween to its end rather than
	# killing it. kill() does NOT emit finished,
	# so the await above would hang forever and
	# the buttons would never appear.
	if credits_tween != null and credits_tween.is_valid():
		credits_tween.custom_step(CREDITS_SCROLL_TIME)


# ============================================
# FIT ANIMATION TO SCREEN
# ============================================

func fit_animation() -> void:

	ScreenFit.cover(win_anim, size)

	# Keep the buttons locked to the artwork.
	# Their offsets are written in frame pixels
	# relative to the center of the frame.
	if win_anim.sprite_frames != null:
		buttons.position = (
			win_anim.position + win_anim.offset * win_anim.scale.x
		)
		buttons.scale = win_anim.scale
	else:
		# No art yet - just center them on screen
		buttons.position = size / 2.0
		buttons.scale = Vector2.ONE


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
