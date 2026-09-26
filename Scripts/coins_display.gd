extends Control


# ============================================
# NODES
# ============================================

@onready var coin_text: Label = $CoinText


# ============================================
# VARIABLES
# ============================================

var player: Node = null


# ============================================
# READY
# ============================================

func _ready() -> void:
	call_deferred("connect_to_player")


# ============================================
# CONNECT TO PLAYER
# ============================================

func connect_to_player() -> void:
	player = get_tree().get_first_node_in_group("player")

	if player == null:
		print("ERROR: CoinsDisplay could not find Player!")
		return

	if player.has_signal("coins_changed"):
		player.coins_changed.connect(_on_coins_changed)

	# Display starting amount.
	_on_coins_changed(player.coins)


# ============================================
# UPDATE COIN DISPLAY
# ============================================

func _on_coins_changed(current_coins: int) -> void:
	coin_text.text = str(current_coins)
