# ==========================================
# FILE: xCardData.gd
# DESCRIPTION: Resource defining a single UNO card's properties with a global class name.
# VERSION: v0.006
# LAST EDITED: v0.006
# ==========================================
extends Resource
class_name xCardData

enum CardColor { RED, BLUE, GREEN, YELLOW, WILD }
enum Type { NUMBER, SKIP, REVERSE, DRAW_TWO, WILD, WILD_DRAW_FOUR }

@export var card_color: CardColor
@export var type: Type
@export var value: int = -1

# 1. _init
# DESCRIPTION: Constructor for the card resource.
# LAST EDITED: v0.001
func _init(p_color = CardColor.RED, p_type = Type.NUMBER, p_value = -1):
	card_color = p_color
	type = p_type
	value = p_value
