# ==========================================
# FILE: CardFactory.gd
# DESCRIPTION: Builds starter decks, enemy decks, reward cards and shop prices.
# VERSION: v0.100
# ==========================================
class_name CardFactory
extends RefCounted

const COLORS := [CardData.CardColor.RED, CardData.CardColor.BLUE, CardData.CardColor.GREEN, CardData.CardColor.YELLOW]
const COLORED_ACTIONS := [CardData.Type.SKIP, CardData.Type.REVERSE, CardData.Type.DRAW_TWO, CardData.Type.DISCARD_ALL]

static func random_color() -> int:
	return COLORS.pick_random()

static func number(color: int, value: int) -> CardData:
	return CardData.new(color, CardData.Type.NUMBER, value)

static func action(color: int, type: int) -> CardData:
	return CardData.new(color, type)

static func wild(type: int = CardData.Type.WILD) -> CardData:
	return CardData.new(CardData.CardColor.WILD, type)

# starter_deck
# DESCRIPTION: The 24-card deck every run begins with.
static func starter_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	for c in COLORS:
		for i in range(1, 5):
			deck.append(number(c, i))
	deck.append(action(CardData.CardColor.RED, CardData.Type.SKIP))
	deck.append(action(CardData.CardColor.BLUE, CardData.Type.SKIP))
	deck.append(action(CardData.CardColor.GREEN, CardData.Type.DRAW_TWO))
	deck.append(action(CardData.CardColor.YELLOW, CardData.Type.DRAW_TWO))
	deck.append(wild())
	deck.append(wild())
	deck.append(wild(CardData.Type.WILD_DRAW_FOUR))
	deck.append(wild(CardData.Type.WILD_DRAW_FOUR))
	return deck

# enemy_deck
# DESCRIPTION: Builds an enemy deck from an archetype name. Later acts add extra power cards.
static func enemy_deck(kind: String, act: int) -> Array[CardData]:
	var deck: Array[CardData] = []
	var max_number := 6
	var actions := {}
	var wilds := 1
	var draw_fours := 1
	match kind:
		"basic":
			actions = {CardData.Type.SKIP: 2, CardData.Type.REVERSE: 2, CardData.Type.DRAW_TWO: 2}
		"colorful":
			max_number = 8
			actions = {CardData.Type.SKIP: 1, CardData.Type.DRAW_TWO: 1}
			wilds = 2
			draw_fours = 0
		"actions":
			max_number = 5
			actions = {CardData.Type.SKIP: 4, CardData.Type.REVERSE: 2, CardData.Type.DRAW_TWO: 4}
		"draw_heavy":
			max_number = 5
			actions = {CardData.Type.SKIP: 2, CardData.Type.DRAW_TWO: 6}
			wilds = 0
			draw_fours = 2
		"strong":
			actions = {CardData.Type.SKIP: 3, CardData.Type.REVERSE: 2, CardData.Type.DRAW_TWO: 3, CardData.Type.DISCARD_ALL: 2}
			wilds = 2
			draw_fours = 2
	for c in COLORS:
		for i in range(1, max_number + 1):
			deck.append(number(c, i))
	for t in actions:
		for i in actions[t]:
			deck.append(action(random_color(), t))
	for i in wilds:
		deck.append(wild())
	for i in draw_fours:
		deck.append(wild(CardData.Type.WILD_DRAW_FOUR))
	for i in range(act - 1):
		deck.append(action(random_color(), COLORED_ACTIONS.pick_random()))
		deck.append(action(random_color(), CardData.Type.DRAW_TWO))
		deck.append(wild([CardData.Type.WILD, CardData.Type.WILD_DRAW_FOUR].pick_random()))
	deck.shuffle()
	return deck

# card_of_rarity
# DESCRIPTION: Rolls a random card of the requested rarity.
static func card_of_rarity(rarity: int) -> CardData:
	match rarity:
		CardData.Rarity.COMMON:
			return number(random_color(), randi_range(0, 9))
		CardData.Rarity.UNCOMMON:
			return action(random_color(), COLORED_ACTIONS.pick_random())
	var roll := randf()
	if roll < 0.45:
		return wild()
	if roll < 0.85:
		return wild(CardData.Type.WILD_DRAW_FOUR)
	return wild(CardData.Type.WILD_SWAP)

# reward_card
# DESCRIPTION: A random card for rewards and shops. Elites and later acts roll better.
static func reward_card(act: int = 1, bonus: float = 0.0) -> CardData:
	var roll := randf() - bonus - (act - 1) * 0.04
	var rarity := CardData.Rarity.COMMON
	if roll < 0.14:
		rarity = CardData.Rarity.RARE
	elif roll < 0.5:
		rarity = CardData.Rarity.UNCOMMON
	var card := card_of_rarity(rarity)
	if randf() < 0.08 + 0.05 * act + bonus * 0.5:
		card.enchant = randi_range(1, CardData.Enchant.size() - 1) as CardData.Enchant
	return card

# reward_choices
# DESCRIPTION: Returns `count` distinct-looking reward cards.
static func reward_choices(count: int, act: int, bonus: float = 0.0) -> Array[CardData]:
	var out: Array[CardData] = []
	var seen := {}
	var guard := 0
	while out.size() < count and guard < 50:
		guard += 1
		var c := reward_card(act, bonus)
		if seen.has(c.title()):
			continue
		seen[c.title()] = true
		out.append(c)
	return out

# price
# DESCRIPTION: Shop price for a card before discounts.
static func price(card: CardData) -> int:
	var base := 25
	match card.rarity():
		CardData.Rarity.UNCOMMON:
			base = 45
		CardData.Rarity.RARE:
			base = 75
	if card.enchant != CardData.Enchant.NONE:
		base += 20
	return base + randi_range(-3, 3)
