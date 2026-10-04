extends Control


# ============================================
# NODES
# ============================================

@onready var wave_text: Label = $WaveText
@onready var status_text: Label = $StatusText

@onready var boss_health: Control = $BossHealth
@onready var boss_health_bar: TextureProgressBar = $BossHealth/BossHealthBar
@onready var boss_health_text: Label = $BossHealth/BossHealthText


# ============================================
# WAVE MANAGER
# ============================================

var wave_manager: Node = null


# ============================================
# COUNTDOWN
# ============================================

var countdown_active: bool = false


# ============================================
# READY
# ============================================

func _ready() -> void:
	boss_health.visible = false
	connect_to_wave_manager()


# ============================================
# CONNECT TO WAVE MANAGER
# ============================================

func connect_to_wave_manager() -> void:
	wave_manager = get_tree().get_first_node_in_group("wave_manager")

	if wave_manager == null:
		print("ERROR: WaveDisplay could not find WaveManager!")
		return

	wave_manager.wave_countdown_started.connect(_on_wave_countdown_started)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.enemy_count_changed.connect(_on_enemy_count_changed)
	wave_manager.boss_started.connect(_on_boss_started)
	wave_manager.boss_defeated.connect(_on_boss_defeated)
	wave_manager.all_waves_completed.connect(_on_all_waves_completed)


# ============================================
# PROCESS COUNTDOWN
# ============================================

func _process(_delta: float) -> void:
	if not countdown_active:
		return

	if wave_manager == null:
		return

	if not wave_manager.wave_waiting:
		countdown_active = false
		return

	var countdown_time: float = wave_manager.get_countdown_remaining()
	var seconds_remaining: int = ceili(countdown_time)

	status_text.text = "STARTING IN " + str(seconds_remaining) + "..."


# ============================================
# WAVE COUNTDOWN STARTED
# ============================================

func _on_wave_countdown_started(wave_number: int, duration: float) -> void:
	wave_text.text = "WAVE " + str(wave_number)

	boss_health.visible = false

	if duration <= 0.0:
		countdown_active = false
		status_text.text = ""
		return

	countdown_active = true

	var seconds_remaining: int = ceili(duration)

	status_text.text = "STARTING IN " + str(seconds_remaining) + "..."


# ============================================
# WAVE STARTED
# ============================================

func _on_wave_started(wave_number: int) -> void:
	countdown_active = false

	wave_text.text = "WAVE " + str(wave_number)


# ============================================
# ENEMY COUNT CHANGED
# ============================================

func _on_enemy_count_changed(enemies_remaining: int) -> void:
	status_text.text = "ENEMIES REMAINING: " + str(enemies_remaining)


# ============================================
# BOSS STARTED
# ============================================

func _on_boss_started(boss: Node) -> void:
	status_text.text = "KILL THE BOSS"

	boss_health.visible = true

	var current_health: int = boss.get("current_health")
	var max_health: int = boss.get("max_health")

	update_boss_health(current_health, max_health)

	if boss.has_signal("health_changed"):
		boss.health_changed.connect(update_boss_health)


# ============================================
# UPDATE BOSS HEALTH
# ============================================

func update_boss_health(current_health: int, max_health: int) -> void:
	boss_health_bar.max_value = max_health
	boss_health_bar.value = maxi(current_health, 0)

	boss_health_text.text = str(maxi(current_health, 0)) + " / " + str(max_health)


# ============================================
# BOSS DEFEATED
# ============================================

func _on_boss_defeated() -> void:
	boss_health.visible = false


# ============================================
# ALL WAVES COMPLETE
# ============================================

func _on_all_waves_completed() -> void:
	countdown_active = false

	wave_text.text = "YOU COMPLEATED ALL WAVES"
	status_text.text = "YOU WIN!"

	boss_health.visible = false
