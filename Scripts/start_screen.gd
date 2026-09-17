extends Control

func _ready() -> void:
	$Start/Start.pressed.connect(_on_start_pressed)
	$Start/Exit.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
