extends Node2D

var direction: Vector2 = Vector2.RIGHT
var spread_angle: float = 5.0
var cone_length: float = 200.0
var cone_start_distance: float = 12.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var half_spread = deg_to_rad(spread_angle / 2.0)

	var start_center = Vector2.RIGHT * cone_start_distance
	var end_center = Vector2.RIGHT * cone_length

	var start_half_width = tan(half_spread) * cone_start_distance
	var end_half_width = tan(half_spread) * cone_length

	var start_top = start_center + Vector2(0, -start_half_width)
	var start_bottom = start_center + Vector2(0, start_half_width)

	var end_top = end_center + Vector2(0, -end_half_width)
	var end_bottom = end_center + Vector2(0, end_half_width)

	draw_colored_polygon(
		PackedVector2Array([
			start_top,
			end_top,
			end_bottom,
			start_bottom
		]),
		Color(1.0, 0.0, 0.0, 0.10)
	)

	draw_line(
		start_top,
		end_top,
		Color(1.0, 0.0, 0.0, 0.45),
		1.0
	)

	draw_line(
		start_bottom,
		end_bottom,
		Color(1.0, 0.0, 0.0, 0.45),
		1.0
	)
