extends Control


# ============================================
# NODES
# ============================================

@onready var ammo_sprite: AnimatedSprite2D = $Ammo
@onready var ammo_text: Label = $AmmoText


# ============================================
# AMMO SETTINGS
# ============================================

const AMMO_FRAME_COUNT: int = 11
const EMPTY_FRAME: int = 10
const EMPTY_ANIMATION_MAX_TIME: float = 0.25


# ============================================
# AMMO VARIABLES
# ============================================

var current_ammo: int = 0
var magazine_size: int = 0
var current_ammo_frame: int = 0
var is_reloading: bool = false

var current_gun: Gun = null
var reload_id: int = 0


# ============================================
# READY
# ============================================

func _ready() -> void:
	call_deferred("connect_to_gun")


# ============================================
# CONNECT TO GUN
# ============================================

func connect_to_gun() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")

	if player == null:
		print("ERROR: WeaponDisplay could not find Player!")
		return

	var gun: Gun = player.get_node_or_null("WeaponHolder/Gun") as Gun

	if gun == null:
		print("ERROR: WeaponDisplay could not find Gun!")
		return

	current_gun = gun

	if not current_gun.ammo_changed.is_connected(update_ammo):
		current_gun.ammo_changed.connect(update_ammo)

	if not current_gun.reload_started.is_connected(start_reload):
		current_gun.reload_started.connect(start_reload)

	if not current_gun.reload_finished.is_connected(finish_reload):
		current_gun.reload_finished.connect(finish_reload)

	if not current_gun.weapon_changed.is_connected(weapon_changed):
		current_gun.weapon_changed.connect(weapon_changed)

	# Initial HUD state
	if current_gun.weapon_instance != null:
		update_ammo(
			current_gun.current_ammo,
			current_gun.weapon_instance.get_magazine_size()
		)


# ============================================
# WEAPON CHANGED
# ============================================

func weapon_changed() -> void:
	# Invalidates any old reload animation
	reload_id += 1
	is_reloading = false

	# Stop whatever animation was playing
	ammo_sprite.stop()
	ammo_sprite.speed_scale = 1.0
	ammo_sprite.animation = "ammo"


# ============================================
# UPDATE AMMO
# ============================================

func update_ammo(new_ammo: int, new_magazine_size: int) -> void:
	current_ammo = new_ammo
	magazine_size = new_magazine_size

	if magazine_size <= 0:
		return

	ammo_text.text = str(current_ammo)

	if is_reloading:
		return

	update_ammo_frame()


# ============================================
# UPDATE AMMO FRAME
# ============================================

func update_ammo_frame() -> void:
	var ammo_used_percent: float = 1.0 - (float(current_ammo) / float(magazine_size))

	current_ammo_frame = roundi(ammo_used_percent * float(AMMO_FRAME_COUNT - 1))
	current_ammo_frame = clampi(current_ammo_frame, 0, EMPTY_FRAME)

	ammo_sprite.stop()
	ammo_sprite.speed_scale = 1.0
	ammo_sprite.animation = "ammo"
	ammo_sprite.frame = current_ammo_frame


# ============================================
# START RELOAD
# ============================================

func start_reload(reload_duration: float) -> void:
	if is_reloading:
		return

	is_reloading = true

	# Give this reload its own ID
	reload_id += 1
	var this_reload_id: int = reload_id

	var starting_frame: int = current_ammo_frame
	var frames_to_empty: int = EMPTY_FRAME - starting_frame
	var empty_time: float = 0.0

	# ============================================
	# QUICKLY EMPTY REMAINING AMMO
	# ============================================

	if frames_to_empty > 0:
		empty_time = minf(EMPTY_ANIMATION_MAX_TIME, reload_duration * 0.20)
		var time_per_frame: float = empty_time / float(frames_to_empty)

		ammo_sprite.stop()
		ammo_sprite.animation = "ammo"

		for frame_number: int in range(starting_frame + 1, EMPTY_FRAME + 1):
			# Stop if weapon changed
			if this_reload_id != reload_id:
				return

			ammo_sprite.frame = frame_number

			await get_tree().create_timer(time_per_frame).timeout

			# Check again after await
			if this_reload_id != reload_id:
				return

	# ============================================
	# CHECK RELOAD STILL VALID
	# ============================================

	if this_reload_id != reload_id:
		return

	# ============================================
	# PLAY RELOAD ANIMATION
	# ============================================

	var remaining_reload_time: float = reload_duration - empty_time
	play_reload_animation(remaining_reload_time)


# ============================================
# PLAY RELOAD ANIMATION
# ============================================

func play_reload_animation(duration: float) -> void:
	ammo_sprite.animation = "reload"

	var frame_count: int = ammo_sprite.sprite_frames.get_frame_count("reload")
	var fps: float = ammo_sprite.sprite_frames.get_animation_speed("reload")

	if frame_count <= 0 or fps <= 0.0:
		return

	var normal_animation_length: float = float(frame_count) / fps

	if duration > 0.0:
		ammo_sprite.speed_scale = normal_animation_length / duration
	else:
		ammo_sprite.speed_scale = 1.0

	ammo_sprite.play("reload")


# ============================================
# FINISH RELOAD
# ============================================

func finish_reload() -> void:
	if current_gun == null:
		return

	if current_gun.weapon_instance == null:
		return

	is_reloading = false

	current_ammo = current_gun.current_ammo
	magazine_size = current_gun.weapon_instance.get_magazine_size()

	ammo_text.text = str(current_ammo)

	update_ammo_frame()
