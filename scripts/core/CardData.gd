# ==========================================
# FILE: CardData.gd
# DESCRIPTION: Resource describing a single DOS card: colour, type, value and enchantment.
# VERSION: v0.100
# ==========================================
class_name CardData
extends Resource

enum CardColor { RED, BLUE, GREEN, YELLOW, WILD }
enum Type { NUMBER, SKIP, REVERSE, DRAW_TWO, WILD, WILD_DRAW_FOUR, DISCARD_ALL, WILD_SWAP }
enum Enchant { NONE, GILDED, BARBED, HEALING }
enum Rarity { COMMON, UNCOMMON, RARE }

const COLOR_NAMES := ["Red", "Blue", "Green", "Yellow", "Wild"]
const TYPE_NAMES := ["Number", "Skip", "Reverse", "Draw Two", "Wild", "Wild Draw Four", "Discard All", "Wild Swap"]
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
	return CardData.new(card_color, type, value, enchant)

func is_wild() -> bool:
	return card_color == CardColor.WILD

func is_action() -> bool:
	return type != Type.NUMBER

func is_draw_card() -> bool:
	return type == Type.DRAW_TWO or type == Type.WILD_DRAW_FOUR

# effective_color
# DESCRIPTION: The colour this card counts as on the pile (the declared colour for wilds).
func effective_color() -> int:
	if is_wild():
		return chosen_color
	return card_color

# rarity
# DESCRIPTION: Used for shop prices and reward rolls.
func rarity() -> Rarity:
	match type:
		Type.NUMBER:
			return Rarity.COMMON
		Type.SKIP, Type.REVERSE, Type.DRAW_TWO, Type.DISCARD_ALL:
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
	if enchant != Enchant.NONE:
		text += "\n" + ENCHANT_DESCRIPTIONS[enchant]
	return text

# sort_key
# DESCRIPTION: Stable ordering for deck views: colour, then type, then value.
func sort_key() -> int:
	return card_color * 1000 + type * 20 + max(value, 0)
