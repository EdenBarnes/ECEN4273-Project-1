extends TextureRect


# ============================================
# SLOT DATA
# ============================================

var slot_index: int = 0
var perk_name: String = ""
var is_empty: bool = true


# ============================================
# SETUP
# ============================================

func setup(index: int, blank_texture: Texture2D) -> void:
	slot_index = index
	perk_name = ""
	is_empty = true
	texture = blank_texture


# ============================================
# SET PERK
# ============================================

func set_perk(new_perk_name: String, perk_texture: Texture2D) -> void:
	perk_name = new_perk_name
	is_empty = false
	texture = perk_texture


# ============================================
# CLEAR PERK
# ============================================

func clear_perk(blank_texture: Texture2D) -> void:
	perk_name = ""
	is_empty = true
	texture = blank_texture
