# ==========================================
# FILE: Charms.gd
# DESCRIPTION: Passive run modifiers ("charms", i.e. relics). Effects are checked where they apply.
# VERSION: v0.100
# ==========================================
class_name Charms
extends RefCounted

# icon: a Glyph name, or "text:XX" for a monogram.
const DATA := {
	"lucky_coin": {"name": "Lucky Coin", "desc": "Gain 10 extra gold after every victory.", "icon": "coin", "color": Color(0.96, 0.77, 0.26), "rarity": 0},
	"iron_heart": {"name": "Iron Heart", "desc": "Raise your max HP by 12.", "icon": "heart", "color": Color(0.9, 0.3, 0.35), "rarity": 0},
	"heavy_burden": {"name": "Heavy Burden", "desc": "Opponents start each battle with 1 extra card.", "icon": "text:+1", "color": Color(0.6, 0.45, 0.85), "rarity": 1},
	"light_pack": {"name": "Light Pack", "desc": "You start each battle with 1 fewer card.", "icon": "text:-1", "color": Color(0.3, 0.8, 0.75), "rarity": 1},
	"vampire_fang": {"name": "Vampire Fang", "desc": "Heal 2 HP whenever you play a Draw Two or Wild Draw Four.", "icon": "fang", "color": Color(0.75, 0.15, 0.25), "rarity": 0},
	"prism": {"name": "Prism", "desc": "Your Wild cards also make the opponent draw 1.", "icon": "diamond", "color": Color(0.85, 0.85, 0.95), "rarity": 1},
	"mirror_shard": {"name": "Mirror Shard", "desc": "Your Reverse cards also make the opponent draw 1.", "icon": "reverse", "color": Color(0.45, 0.8, 0.95), "rarity": 0},
	"pickpocket": {"name": "Pickpocket", "desc": "Gain 1 gold for every card you play.", "icon": "text:+$", "color": Color(0.8, 0.6, 0.3), "rarity": 0},
	"thick_skin": {"name": "Thick Skin", "desc": "Take 30% less damage from lost battles.", "icon": "shield", "color": Color(0.55, 0.65, 0.75), "rarity": 0},
	"megaphone": {"name": "Megaphone", "desc": "DOS! is called automatically for you.", "icon": "text:DOS", "color": Color(0.95, 0.5, 0.2), "rarity": 0},
	"seer": {"name": "Seer's Eye", "desc": "The top card of your draw pile is always revealed.", "icon": "eye", "color": Color(0.4, 0.6, 0.95), "rarity": 1},
	"spyglass": {"name": "Spyglass", "desc": "One card in the opponent's hand is always revealed.", "icon": "search", "color": Color(0.7, 0.75, 0.4), "rarity": 0},
	"rubber_gloves": {"name": "Rubber Gloves", "desc": "The first draw penalty against you each battle is reduced by 2.", "icon": "text:-2", "color": Color(0.95, 0.85, 0.3), "rarity": 0},
	"phoenix_feather": {"name": "Phoenix Feather", "desc": "The first time you would die, revive at 50% HP. (Consumed)", "icon": "flame", "color": Color(1.0, 0.5, 0.2), "rarity": 2},
	"deep_pockets": {"name": "Deep Pockets", "desc": "Shop prices are 25% lower.", "icon": "bag", "color": Color(0.35, 0.75, 0.45), "rarity": 0},
	# Trick-card synergies
	"harlequin": {"name": "Harlequin Mask", "desc": "Your dual-colour cards can be played on anything.", "icon": "mask", "color": Color(0.95, 0.45, 0.65), "rarity": 2},
	"high_roller": {"name": "High Roller", "desc": "Your Double Down has no limit. Push them over 25 cards to Bust them!", "icon": "dice", "color": Color(0.95, 0.35, 0.3), "rarity": 1},
	"permafrost": {"name": "Permafrost", "desc": "Your Freeze cards give 3 extra turns instead of 2.", "icon": "snowflake", "color": Color(0.55, 0.85, 1.0), "rarity": 1},
	"wrapping_paper": {"name": "Wrapping Paper", "desc": "Your Gift cards give away 1 more card, and earn 3 gold per card gifted.", "icon": "gift", "color": Color(0.9, 0.4, 0.6), "rarity": 0},
	"clockwork": {"name": "Clockwork", "desc": "Heal 1 HP at the start of every extra turn you take (Skip, Freeze, Chain...).", "icon": "clock", "color": Color(0.85, 0.7, 0.4), "rarity": 0},
	"funhouse_mirror": {"name": "Funhouse Mirror", "desc": "Your Wild Mirror also makes the opponent draw 2.", "icon": "mirror", "color": Color(0.7, 0.6, 1.0), "rarity": 0},
	"jokers_grin": {"name": "Joker's Grin", "desc": "Start every battle with a free random trick card in your hand.", "icon": "joker", "color": Color(0.6, 0.85, 0.35), "rarity": 1},
	"tricksters_pact": {"name": "Trickster's Pact", "desc": "Trick cards appear far more often in rewards, shops and events.", "icon": "cards", "color": Color(0.75, 0.6, 1.0), "rarity": 0},
}

static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {"name": id, "desc": "", "icon": "text:?", "color": Color.GRAY, "rarity": 0})

static func price(id: String) -> int:
	return [90, 120, 150][get_def(id).rarity] + randi_range(-5, 5)

# random_unowned
# DESCRIPTION: Picks up to `count` charms the player doesn't own yet.
static func random_unowned(owned: Array, count: int) -> Array[String]:
	var pool: Array = DATA.keys().filter(func(k): return not owned.has(k))
	pool.shuffle()
	var out: Array[String] = []
	for i in min(count, pool.size()):
		out.append(pool[i])
	return out
