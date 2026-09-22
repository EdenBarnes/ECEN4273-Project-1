extends Control

@onready var flash: ColorRect = $Flash
@onready var bolts: Array[TextureRect] = [$Bolt, $Bolt2]
@onready var thunder: AudioStreamPlayer = $Thunder

func _ready() -> void:
	$Start/Start.pressed.connect(_on_start_pressed)
	$Start/Exit.pressed.connect(_on_quit_pressed)
	_schedule_strike()

#-------------------------------------------------
#                 BUTTONS 
#-------------------------------------------------

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

#-------------------------------------------------
#                 Lightning Functions 
#-------------------------------------------------
	
func _schedule_strike() -> void:
	await get_tree().create_timer(randf_range(2.5, 7.0)).timeout
	_strike()
	_schedule_strike()

func _strike() -> void:
	var active: Array = bolts if randf() < 0.2 else [bolts.pick_random()]
	for b in active:
		b.visible = true
	var t := create_tween()
	t.tween_property(flash, "color:a", 0.85, 0.04)
	t.tween_property(flash, "color:a", 0.05, 0.07)
	t.tween_property(flash, "color:a", 0.65, 0.05)
	t.tween_callback(func():
		for b in active:
			b.visible = false)
	t.tween_property(flash, "color:a", 0.0, 0.35)
	await get_tree().create_timer(randf_range(0.4, 1.2)).timeout
	thunder.pitch_scale = randf_range(0.8, 1.15)
	thunder.volume_db = randf_range(-8.0, 0.0)
	thunder.play()
