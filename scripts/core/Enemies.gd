# ==========================================
# FILE: Enemies.gd
# DESCRIPTION: Opponent roster for each act: regular foes, elites and bosses, plus ability text.
# VERSION: v0.100
# ==========================================
class_name Enemies
extends RefCounted

const ABILITY_TEXT := {
	"spiky": "Spiky: their Draw Two cards make you draw 3.",
	"lockdown": "Lockdown: you can't play Wild cards during your first 3 turns.",
	"tax": "House Tax: every 4th turn they take, you draw a card.",
	"chroma": "Chroma Shift: every 3rd turn they take, the active colour changes.",
	"quick": "Quick Start: they begin with one fewer card.",
	"thorns": "Thorns: you lose 1 HP whenever you play an action card.",
	"frostbite": "Frostbite: their Freeze cards give them 3 extra turns.",
	"jackpot": "Jackpot: their Double Down has no limit.",
	"generous": "Generous: their Gift cards give you 3 cards.",
}

const ACT_NAMES := ["The Back Alley", "The Velvet Casino", "The Hall of Quietus"]

# Fields: name, title, color, style, deck, attack (damage per card left in your hand),
# hand, quiet_call (chance they remember to call QUIET!), catch (chance they catch you), gold, abilities.
const ROSTER := {
	1: {
		"battle": [
			{"name": "Pip", "title": "Pocket Magician", "color": Color(0.55, 0.75, 0.4), "style": "aggressive", "deck": "tricky", "attack": 2, "hand": 7, "quiet_call": 0.6, "catch": 0.5, "gold": 16, "abilities": []},
			{"name": "Paul", "title": "The Novice", "color": Color(0.42, 0.56, 0.75), "style": "random", "deck": "basic", "attack": 2, "hand": 7, "quiet_call": 0.55, "catch": 0.35, "gold": 14, "abilities": []},
			{"name": "Tilly", "title": "Weekend Tourist", "color": Color(0.85, 0.55, 0.3), "style": "random", "deck": "colorful", "attack": 2, "hand": 7, "quiet_call": 0.65, "catch": 0.45, "gold": 14, "abilities": []},
			{"name": "Grizzle", "title": "Sore Loser", "color": Color(0.55, 0.42, 0.32), "style": "aggressive", "deck": "actions", "attack": 2, "hand": 7, "quiet_call": 0.7, "catch": 0.6, "gold": 16, "abilities": []},
			{"name": "Mona", "title": "Card Counter", "color": Color(0.6, 0.4, 0.75), "style": "smart", "deck": "basic", "attack": 2, "hand": 7, "quiet_call": 0.9, "catch": 0.8, "gold": 16, "abilities": []},
		],
		"elite": [
			{"name": "Patchwork Pete", "title": "Two-Tone Terror", "color": Color(0.95, 0.45, 0.65), "style": "smart", "deck": "two_tone", "attack": 3, "hand": 7, "quiet_call": 0.85, "catch": 0.8, "gold": 34, "abilities": []},
			{"name": "The Twins", "title": "Double Trouble", "color": Color(0.85, 0.3, 0.45), "style": "aggressive", "deck": "draw_heavy", "attack": 3, "hand": 7, "quiet_call": 0.8, "catch": 0.7, "gold": 32, "abilities": ["spiky"]},
			{"name": "Sir Lockwood", "title": "The Gatekeeper", "color": Color(0.45, 0.55, 0.6), "style": "smart", "deck": "basic", "attack": 3, "hand": 7, "quiet_call": 0.85, "catch": 0.8, "gold": 32, "abilities": ["lockdown"]},
		],
		"boss": [
			{"name": "The Croupier", "title": "The House Always Wins", "color": Color(0.8, 0.15, 0.2), "style": "smart", "deck": "strong", "attack": 3, "hand": 7, "quiet_call": 0.95, "catch": 0.9, "gold": 60, "abilities": ["tax"]},
		],
	},
	2: {
		"battle": [
			{"name": "Frost", "title": "Ice-Cold Card Sharp", "color": Color(0.55, 0.85, 1.0), "style": "smart", "deck": "frosty", "attack": 3, "hand": 7, "quiet_call": 0.85, "catch": 0.8, "gold": 20, "abilities": ["frostbite"]},
			{"name": "Kringle", "title": "Unwanted Gifter", "color": Color(0.85, 0.25, 0.3), "style": "aggressive", "deck": "giving", "attack": 3, "hand": 7, "quiet_call": 0.8, "catch": 0.75, "gold": 20, "abilities": ["generous"]},
			{"name": "Rook", "title": "Street Hustler", "color": Color(0.3, 0.6, 0.55), "style": "smart", "deck": "actions", "attack": 3, "hand": 7, "quiet_call": 0.85, "catch": 0.75, "gold": 18, "abilities": []},
			{"name": "Vex", "title": "Thorny Rose", "color": Color(0.75, 0.2, 0.4), "style": "aggressive", "deck": "basic", "attack": 3, "hand": 7, "quiet_call": 0.8, "catch": 0.7, "gold": 18, "abilities": ["thorns"]},
			{"name": "Bramble", "title": "Quick Fingers", "color": Color(0.4, 0.65, 0.3), "style": "smart", "deck": "basic", "attack": 3, "hand": 7, "quiet_call": 0.85, "catch": 0.8, "gold": 18, "abilities": ["quick"]},
			{"name": "Dot", "title": "The Collector", "color": Color(0.9, 0.7, 0.25), "style": "random", "deck": "strong", "attack": 3, "hand": 7, "quiet_call": 0.7, "catch": 0.6, "gold": 20, "abilities": []},
		],
		"elite": [
			{"name": "Gambler Gus", "title": "High Stakes", "color": Color(0.95, 0.35, 0.3), "style": "aggressive", "deck": "high_stakes", "attack": 4, "hand": 7, "quiet_call": 0.9, "catch": 0.85, "gold": 42, "abilities": ["jackpot"]},
			{"name": "Duchess Vale", "title": "Velvet Thorn", "color": Color(0.55, 0.2, 0.55), "style": "smart", "deck": "draw_heavy", "attack": 4, "hand": 7, "quiet_call": 0.9, "catch": 0.85, "gold": 40, "abilities": ["spiky", "thorns"]},
			{"name": "Iron Ivan", "title": "The Wall", "color": Color(0.5, 0.5, 0.55), "style": "aggressive", "deck": "actions", "attack": 4, "hand": 7, "quiet_call": 0.9, "catch": 0.85, "gold": 40, "abilities": ["lockdown", "quick"]},
		],
		"boss": [
			{"name": "Madame Chroma", "title": "Mistress of Colour", "color": Color(0.35, 0.3, 0.85), "style": "smart", "deck": "strong", "attack": 4, "hand": 7, "quiet_call": 0.95, "catch": 0.9, "gold": 75, "abilities": ["chroma", "spiky"]},
		],
	},
	3: {
		"battle": [
			{"name": "Clockwork Clara", "title": "Perpetual Motion", "color": Color(0.85, 0.7, 0.4), "style": "smart", "deck": "clockwork", "attack": 4, "hand": 7, "quiet_call": 0.9, "catch": 0.85, "gold": 24, "abilities": ["frostbite"]},
			{"name": "Specter", "title": "Ghost of Games Past", "color": Color(0.6, 0.75, 0.85), "style": "smart", "deck": "strong", "attack": 4, "hand": 7, "quiet_call": 0.9, "catch": 0.85, "gold": 22, "abilities": ["quick"]},
			{"name": "Baron Blitz", "title": "Lightning Dealer", "color": Color(0.95, 0.75, 0.2), "style": "aggressive", "deck": "draw_heavy", "attack": 4, "hand": 7, "quiet_call": 0.9, "catch": 0.85, "gold": 22, "abilities": ["spiky"]},
			{"name": "Lady Luck", "title": "Fortune's Favourite", "color": Color(0.3, 0.75, 0.5), "style": "smart", "deck": "strong", "attack": 4, "hand": 7, "quiet_call": 0.9, "catch": 0.85, "gold": 22, "abilities": ["chroma"]},
			{"name": "Hex", "title": "The Jinx", "color": Color(0.45, 0.25, 0.6), "style": "smart", "deck": "actions", "attack": 4, "hand": 7, "quiet_call": 0.9, "catch": 0.85, "gold": 22, "abilities": ["thorns", "tax"]},
		],
		"elite": [
			{"name": "The Ringmaster", "title": "Circus of Tricks", "color": Color(0.6, 0.85, 0.35), "style": "smart", "deck": "circus", "attack": 5, "hand": 7, "quiet_call": 0.95, "catch": 0.9, "gold": 50, "abilities": ["jackpot", "generous"]},
			{"name": "Mirror Knight", "title": "Reflection of You", "color": Color(0.7, 0.8, 0.9), "style": "smart", "deck": "strong", "attack": 5, "hand": 7, "quiet_call": 0.95, "catch": 0.9, "gold": 48, "abilities": ["lockdown", "spiky"]},
			{"name": "Grand Arbiter", "title": "Keeper of Rules", "color": Color(0.85, 0.65, 0.35), "style": "smart", "deck": "strong", "attack": 5, "hand": 7, "quiet_call": 0.95, "catch": 0.9, "gold": 48, "abilities": ["tax", "quick"]},
		],
		"boss": [
			{"name": "The Jester King", "title": "Fool's Gold", "color": Color(0.75, 0.6, 1.0), "style": "smart", "deck": "circus", "attack": 5, "hand": 7, "quiet_call": 1.0, "catch": 0.95, "gold": 0, "abilities": ["frostbite", "jackpot", "quick"]},
			{"name": "The Dealer", "title": "Keeper of the Ledger", "color": Color(0.9, 0.2, 0.25), "style": "smart", "deck": "strong", "attack": 5, "hand": 7, "quiet_call": 1.0, "catch": 0.95, "gold": 0, "abilities": ["quick", "tax", "spiky"]},
		],
	},
}

# pick
# DESCRIPTION: Returns a copy of a random enemy for the given act and node kind ("battle", "elite", "boss").
static func pick(act: int, kind: String) -> Dictionary:
	var pool: Array = ROSTER[clampi(act, 1, 3)][kind]
	var e: Dictionary = pool.pick_random().duplicate(true)
	e["kind"] = kind
	# Elites are a real step up: they always play smart and start with a smaller hand.
	if kind == "elite":
		e.style = "smart" if e.style == "random" else e.style
		e.hand = mini(e.hand, 6)
	if e.abilities.has("quick"):
		e.hand -= 1
	return e

static func ability_lines(enemy: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for a in enemy.abilities:
		out.append(ABILITY_TEXT.get(a, a))
	return out
