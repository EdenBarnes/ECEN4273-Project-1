extends StaticBody2D


# ============================================
# NODES
# ============================================

@onready var top: CollisionShape2D = $Top
@onready var bottom: CollisionShape2D = $Bottom
@onready var left: CollisionShape2D = $Left
@onready var right: CollisionShape2D = $Right

# ============================================
# MAP SETTINGS
# ============================================

@export_category("Map Settings")
@export var top_boundary_offset: float = 20.0

# Size of the background/map image.
@export var map_size: Vector2 = Vector2(
	1536.0,
	1024.0
)

# Thickness of the invisible walls.
@export var wall_thickness: float = 20.0

# ============================================
# READY
# ============================================

func _ready() -> void:
	call_deferred("setup_boundaries")

# ============================================
# SETUP MAP BOUNDARIES
# ============================================

func setup_boundaries() -> void:

	# ============================================
	# TOP WALL
	# ============================================

	top.position = Vector2(
	map_size.x / 2.0,
	top_boundary_offset - wall_thickness / 2.0
)

	top.shape.size = Vector2(
		map_size.x + wall_thickness * 2.0,
		wall_thickness
	)

	# ============================================
	# BOTTOM WALL
	# ============================================

	bottom.position = Vector2(
		map_size.x / 2.0,
		map_size.y + wall_thickness / 2.0
	)

	bottom.shape.size = Vector2(
		map_size.x + wall_thickness * 2.0,
		wall_thickness
	)

	# ============================================
	# LEFT WALL
	# ============================================

	left.position = Vector2(
		-wall_thickness / 2.0,
		map_size.y / 2.0
	)

	left.shape.size = Vector2(
		wall_thickness,
		map_size.y + wall_thickness * 2.0
	)

	# ============================================
	# RIGHT WALL
	# ============================================

	right.position = Vector2(
		map_size.x + wall_thickness / 2.0,
		map_size.y / 2.0
	)

	right.shape.size = Vector2(
		wall_thickness,
		map_size.y + wall_thickness * 2.0
	)
