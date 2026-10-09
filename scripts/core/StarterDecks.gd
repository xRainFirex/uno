# ==========================================
# FILE: StarterDecks.gd
# DESCRIPTION: The decks a run can start with. Winning a run with a deck unlocks the next one in ORDER.
# VERSION: v0.100
# ==========================================
class_name StarterDecks
extends RefCounted

const ORDER := ["classic", "standard", "monochrome", "two_tone", "trickster", "high_roller"]

# hp/gold are offsets from the normal starting values; charms are granted at the start of the run.
const DATA := {
	"classic": {
		"name": "Classic", "icon": "cards", "color": Color(0.9, 0.22, 0.23),
		"desc": "A small, balanced deck: 1-4 in every colour, a few actions and four Wilds.",
		"perk": "No twist. A solid place to learn.",
		"hp": 0, "gold": 0, "charms": [],
	},
	"standard": {
		"name": "Standard", "icon": "shield", "color": Color(0.12, 0.48, 0.88),
		"desc": "Every number from 1 to 9 in all four colours, a Skip and Draw Two in each, and five Wilds. Big and steady.",
		"perk": "+10 max HP.",
		"hp": 10, "gold": 0, "charms": [],
	},
	"monochrome": {
		"name": "Monochrome", "icon": "diamond", "color": Color(0.95, 0.35, 0.3),
		"desc": "A single colour: 1-9, a Skip, a Reverse and one Wild to steer back home. Just 12 cards.",
		"perk": "Every card chains into the next while the colour is yours. Lose it and you're in trouble.",
		"hp": 0, "gold": 0, "charms": [],
	},
	"two_tone": {
		"name": "Two-Tone", "icon": "mask", "color": Color(0.95, 0.45, 0.65),
		"desc": "Mostly dual-colour numbers, so almost everything matches something.",
		"perk": "Starts with the Prism charm.",
		"hp": 0, "gold": 0, "charms": ["prism"],
	},
	"trickster": {
		"name": "Trickster", "icon": "joker", "color": Color(0.6, 0.85, 0.35),
		"desc": "Low numbers padded out with every trick card: Freeze, Gift, Double Down, Chain and Mirror.",
		"perk": "Starts with Joker's Grin.",
		"hp": 0, "gold": 0, "charms": ["jokers_grin"],
	},
	"high_roller": {
		"name": "High Roller", "icon": "dice", "color": Color(0.96, 0.77, 0.26),
		"desc": "Two colours of 1-9 with a Double Down and two Wild Draw Fours. Hits hard, breaks easily.",
		"perk": "-15 max HP, +80 gold and the Lucky Coin.",
		"hp": -15, "gold": 80, "charms": ["lucky_coin"],
	},
}

static func get_def(id: String) -> Dictionary:
	return DATA.get(id, DATA.classic)

# next_after
# DESCRIPTION: The deck unlocked by winning with `id` ("" if it's the last one).
static func next_after(id: String) -> String:
	var i := ORDER.find(id)
	if i < 0 or i >= ORDER.size() - 1:
		return ""
	return ORDER[i + 1]

# build
# DESCRIPTION: Creates the starting cards for a deck.
static func build(id: String) -> Array[CardData]:
	var deck: Array[CardData] = []
	var colors := CardFactory.COLORS
	match id:
		"standard":
			for c in colors:
				for v in range(1, 10):
					deck.append(CardFactory.number(c, v))
				deck.append(CardFactory.action(c, CardData.Type.SKIP))
				deck.append(CardFactory.action(c, CardData.Type.DRAW_TWO))
			for i in 3:
				deck.append(CardFactory.wild())
			deck.append(CardFactory.wild(CardData.Type.WILD_DRAW_FOUR))
			deck.append(CardFactory.wild(CardData.Type.WILD_DRAW_FOUR))
		"monochrome":
			var c: int = CardFactory.random_color()
			for v in range(1, 10):
				deck.append(CardFactory.number(c, v))
			deck.append(CardFactory.action(c, CardData.Type.SKIP))
			deck.append(CardFactory.action(c, CardData.Type.REVERSE))
			deck.append(CardFactory.wild())
		"two_tone":
			for v in range(1, 9):
				deck.append(CardFactory.dual(v))
				deck.append(CardFactory.dual(v))
			deck.append(CardFactory.action(CardFactory.random_color(), CardData.Type.SKIP))
			deck.append(CardFactory.action(CardFactory.random_color(), CardData.Type.DRAW_TWO))
			deck.append(CardFactory.wild())
			deck.append(CardFactory.wild())
		"trickster":
			for c in colors:
				for v in range(1, 4):
					deck.append(CardFactory.number(c, v))
			deck.append(CardFactory.action(CardFactory.random_color(), CardData.Type.FREEZE))
			deck.append(CardFactory.action(CardFactory.random_color(), CardData.Type.GIFT))
			deck.append(CardFactory.action(CardFactory.random_color(), CardData.Type.GIFT))
			deck.append(CardFactory.action(CardFactory.random_color(), CardData.Type.DOUBLE_DOWN))
			deck.append(CardFactory.wild(CardData.Type.WILD_CHAIN))
			deck.append(CardFactory.wild(CardData.Type.WILD_MIRROR))
			deck.append(CardFactory.dual(randi_range(1, 9)))
			deck.append(CardFactory.dual(randi_range(1, 9)))
			deck.append(CardFactory.wild())
		"high_roller":
			var pair := colors.duplicate()
			pair.shuffle()
			for c in pair.slice(0, 2):
				for v in range(1, 10):
					deck.append(CardFactory.number(c, v))
				deck.append(CardFactory.action(c, CardData.Type.DRAW_TWO))
			deck.append(CardFactory.action(pair[0], CardData.Type.DOUBLE_DOWN))
			deck.append(CardFactory.wild(CardData.Type.WILD_DRAW_FOUR))
			deck.append(CardFactory.wild(CardData.Type.WILD_DRAW_FOUR))
		_:
			deck = CardFactory.starter_deck()
	return deck
