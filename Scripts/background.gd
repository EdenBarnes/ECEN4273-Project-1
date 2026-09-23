extends TextureRect


func _ready():
	resize_background()
	get_viewport().size_changed.connect(resize_background)

func resize_background():
	position = Vector2.ZERO
	size = get_viewport_rect().size
