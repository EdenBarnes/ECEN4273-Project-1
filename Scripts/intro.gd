extends Control

@onready var titlecard: AnimatedSprite2D = $Titlecard
@onready var fade: ColorRect = $Fade

var leaving := false

func _ready() -> void:
	fade.color = Color(0, 0, 0, 0)
	titlecard.play()
	await titlecard.animation_finished
	await get_tree().create_timer(1.0).timeout
	_leave()

func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") \
	or (event is InputEventMouseButton and event.pressed):
		_leave()

func _leave() -> void:
	if leaving:
		return
	leaving = true
	var t := create_tween()
	t.tween_property(fade, "color:a", 1.0, 1.0)
	await t.finished
	get_tree().change_scene_to_file("res://Scenes/start_screen.tscn")
