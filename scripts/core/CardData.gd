# ==========================================
# FILE: CardData.gd
# DESCRIPTION: Resource describing a single DOS card: colour, type, value and enchantment.
# VERSION: v0.100
# ==========================================
class_name CardData
extends Resource

enum CardColor { RED, BLUE, GREEN, YELLOW, WILD }
# New types are appended so existing values never shift.
enum Type { NUMBER, SKIP, REVERSE, DRAW_TWO, WILD, WILD_DRAW_FOUR, DISCARD_ALL, WILD_SWAP, DOUBLE_DOWN, FREEZE, GIFT, WILD_CHAIN, WILD_MIRROR }
enum Enchant { NONE, GILDED, BARBED, HEALING }
enum Rarity { COMMON, UNCOMMON, RARE }

const COLOR_NAMES := ["Red", "Blue", "Green", "Yellow", "Wild"]
const TYPE_NAMES := ["Number", "Skip", "Reverse", "Draw Two", "Wild", "Wild Draw Four", "Discard All", "Wild Swap", "Double Down", "Freeze", "Gift", "Wild Chain", "Wild Mirror"]
const DOUBLE_DOWN_CAP := 6
const GIFT_AMOUNT := 2
const ENCHANT_NAMES := ["", "Gilded", "Barbed", "Healing"]
const ENCHANT_DESCRIPTIONS := [
	"",
	"Gilded: gain 3 gold when played.",
	"Barbed: the opponent draws 1 when played.",
	"Healing: heal 2 HP when played.",
]

@export var card_color: CardColor = CardColor.RED
@export var type: Type = Type.NUMBER
@export var value: int = -1
@export var enchant: Enchant = Enchant.NONE
# Dual-colour cards count as both card_color and second_color (-1 = single colour).
@export var second_color: int = -1

# Runtime-only state used during a battle. Never persisted to the run deck.
var chosen_color: int = -1
var owner_side: int = 0

# _init
# DESCRIPTION: Constructor for the card resource.
func _init(p_color: CardColor = CardColor.RED, p_type: Type = Type.NUMBER, p_value: int = -1, p_enchant: Enchant = Enchant.NONE) -> void:
	card_color = p_color
	type = p_type
	value = p_value
	enchant = p_enchant

# clone
# DESCRIPTION: Returns a fresh copy without any battle state attached.
func clone() -> CardData:
	var c := CardData.new(card_color, type, value, enchant)
	c.second_color = second_color
	return c

func is_wild() -> bool:
	return card_color == CardColor.WILD

func is_dual() -> bool:
	return second_color >= 0 and not is_wild()

# has_color
# DESCRIPTION: True if this card counts as the given colour (either colour for dual cards).
func has_color(color: int) -> bool:
	return card_color == color or (is_dual() and second_color == color)

func colors() -> Array:
	return [card_color, second_color] if is_dual() else [card_color]

func is_action() -> bool:
	return type != Type.NUMBER

func is_draw_card() -> bool:
	return type == Type.DRAW_TWO or type == Type.WILD_DRAW_FOUR

# effective_color
# DESCRIPTION: The colour this card counts as on the pile (the declared colour for wilds and dual cards).
func effective_color() -> int:
	if is_wild():
		return chosen_color
	if is_dual() and chosen_color >= 0:
		return chosen_color
	return card_color

# rarity
# DESCRIPTION: Used for shop prices and reward rolls.
func rarity() -> Rarity:
	match type:
		Type.NUMBER:
			return Rarity.UNCOMMON if is_dual() else Rarity.COMMON
		Type.SKIP, Type.REVERSE, Type.DRAW_TWO, Type.DISCARD_ALL, Type.FREEZE, Type.GIFT:
			return Rarity.UNCOMMON
	return Rarity.RARE

# points
# DESCRIPTION: Classic UNO scoring value, used by the AI to decide what to dump first.
func points() -> int:
	if type == Type.NUMBER:
		return value
	if is_wild():
		return 50
	return 20

func type_name() -> String:
	return TYPE_NAMES[type]

func color_name() -> String:
	if is_dual():
		return "%s/%s" % [COLOR_NAMES[card_color], COLOR_NAMES[second_color]]
	return COLOR_NAMES[card_color]

# title
# DESCRIPTION: Human-readable card name, e.g. "Blue 7" or "Wild Draw Four".
func title() -> String:
	var base: String
	if type == Type.NUMBER:
		base = "%s %d" % [color_name(), value]
	elif is_wild():
		base = type_name()
	else:
		base = "%s %s" % [color_name(), type_name()]
	if enchant != Enchant.NONE:
		base = "%s %s" % [ENCHANT_NAMES[enchant], base]
	return base

# describe
# DESCRIPTION: Rules text shown in tooltips, shops and rewards.
func describe() -> String:
	var text := ""
	match type:
		Type.NUMBER:
			if is_dual():
				text = "Counts as both colours. Choose which colour continues."
			else:
				text = "Match by colour or number."
		Type.SKIP:
			text = "The opponent loses their turn."
		Type.REVERSE:
			text = "Reverses play. With two players, you go again."
		Type.DRAW_TWO:
			text = "The opponent draws 2 and loses their turn."
		Type.WILD:
			text = "Play on anything. Choose the next colour."
		Type.WILD_DRAW_FOUR:
			text = "Choose the colour. The opponent draws 4 and loses their turn."
		Type.DISCARD_ALL:
			text = "Also discard every other card of this colour in your hand."
		Type.WILD_SWAP:
			text = "Choose the colour, then swap hands with the opponent."
		Type.DOUBLE_DOWN:
			text = "The opponent draws as many cards as they hold (max %d)." % DOUBLE_DOWN_CAP
		Type.FREEZE:
			text = "The opponent is frozen: you take two extra turns."
		Type.GIFT:
			text = "Give %d random cards from your hand to the opponent (you always keep at least 1)." % GIFT_AMOUNT
		Type.WILD_CHAIN:
			text = "Choose the colour, then play again."
		Type.WILD_MIRROR:
			text = "Choose the colour and copy the effect of the card it covers."
	if enchant != Enchant.NONE:
		text += "\n" + ENCHANT_DESCRIPTIONS[enchant]
	return text

# sort_key
# DESCRIPTION: Stable ordering for deck views: colour, then type, then value.
func sort_key() -> int:
	return card_color * 1000 + type * 20 + max(value, 0)
