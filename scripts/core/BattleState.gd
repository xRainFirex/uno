# ==========================================
# FILE: BattleState.gd
# DESCRIPTION: Pure rules engine for one battle. Each side draws from its own deck; cards return
#              to their owner's discard when covered on the shared pile. No UI code lives here,
#              so battles can be simulated headless (see tests/sim_battles.gd).
# VERSION: v0.100
# ==========================================
class_name BattleState
extends RefCounted

const PLAYER := 0
const ENEMY := 1

var hands: Array = [[], []]
var draw_piles: Array = [[], []]
var discards: Array = [[], []]
var top_card: CardData
var active_color: int = 0
var current: int = PLAYER
var extra_turn := false
var turn_number: Array[int] = [0, 0]
var charms: Array = []
var abilities: Array = []
var gloves_ready := false
var stuck_in_row := 0

# setup
# DESCRIPTION: Copies both decks (so the run deck is never mutated), shuffles, deals and flips the first card.
func setup(player_deck: Array, enemy_deck: Array, p_charms: Array, p_abilities: Array, player_hand: int, enemy_hand: int) -> void:
	charms = p_charms.duplicate()
	abilities = p_abilities.duplicate()
	gloves_ready = has_charm("rubber_gloves")
	var decks := [player_deck, enemy_deck]
	for side in 2:
		var pile: Array = []
		for card in decks[side]:
			var c: CardData = card.clone()
			c.owner_side = side
			pile.append(c)
		pile.shuffle()
		draw_piles[side] = pile
		hands[side] = []
		discards[side] = []
	for i in max(player_hand, enemy_hand):
		if i < player_hand:
			draw_one(PLAYER)
		if i < enemy_hand:
			draw_one(ENEMY)
	_flip_first_card()
	current = PLAYER

func _flip_first_card() -> void:
	var pile: Array = draw_piles[PLAYER]
	if pile.is_empty():
		pile = draw_piles[ENEMY]
	var idx := pile.size() - 1
	for i in range(pile.size() - 1, -1, -1):
		var c: CardData = pile[i]
		if not c.is_wild() and c.type == CardData.Type.NUMBER:
			idx = i
			break
	top_card = pile[idx]
	pile.remove_at(idx)
	if top_card.is_wild():
		top_card.chosen_color = CardFactory.random_color()
	active_color = top_card.effective_color()

func has_charm(id: String) -> bool:
	return charms.has(id)

func has_ability(id: String) -> bool:
	return abilities.has(id)

# can_play
# DESCRIPTION: Matching rules, including the Lockdown enemy ability.
func can_play(card: CardData, side: int) -> bool:
	if card.is_wild():
		if side == PLAYER and has_ability("lockdown") and turn_number[PLAYER] <= 3:
			return false
		return true
	if card.card_color == active_color:
		return true
	if card.type == top_card.type:
		if card.type == CardData.Type.NUMBER:
			return card.value == top_card.value
		return true
	return false

func playable_cards(side: int) -> Array:
	return hands[side].filter(func(c): return can_play(c, side))

func can_draw(side: int) -> bool:
	return not draw_piles[side].is_empty() or not discards[side].is_empty()

func deck_count(side: int) -> int:
	return draw_piles[side].size()

func discard_count(side: int) -> int:
	return discards[side].size()

func peek_top_of_deck(side: int) -> CardData:
	if draw_piles[side].is_empty():
		return null
	return draw_piles[side].back()

# draw_one
# DESCRIPTION: Draws from the side's own deck, reshuffling their discard if needed. Returns null when exhausted.
func draw_one(side: int) -> CardData:
	if draw_piles[side].is_empty():
		if discards[side].is_empty():
			return null
		draw_piles[side] = discards[side].duplicate()
		draw_piles[side].shuffle()
		discards[side] = []
	var card: CardData = draw_piles[side].pop_back()
	hands[side].append(card)
	stuck_in_row = 0
	return card

func draw_many(side: int, amount: int) -> Array:
	var drawn: Array = []
	for i in amount:
		var c := draw_one(side)
		if c == null:
			break
		drawn.append(c)
	return drawn

# begin_turn
# DESCRIPTION: Start-of-turn enemy abilities (House Tax, Chroma Shift).
func begin_turn(side: int) -> Dictionary:
	turn_number[side] += 1
	var res := {"forced": [], "color_shift": -1, "texts": []}
	if side == ENEMY:
		if has_ability("tax") and turn_number[ENEMY] % 4 == 0:
			res.forced = draw_many(PLAYER, 1)
			res.texts.append("HOUSE TAX")
		if has_ability("chroma") and turn_number[ENEMY] % 3 == 0:
			var options := CardFactory.COLORS.filter(func(c): return c != active_color)
			active_color = options.pick_random()
			if top_card.is_wild():
				top_card.chosen_color = active_color
			res.color_shift = active_color
			res.texts.append("CHROMA SHIFT")
	return res

func _retire_top() -> void:
	if top_card == null:
		return
	top_card.chosen_color = -1
	discards[top_card.owner_side].append(top_card)
	top_card = null

# play
# DESCRIPTION: Plays a card and resolves every effect. Returns a description of what happened for the UI.
func play(side: int, card: CardData, chosen: int = -1) -> Dictionary:
	var opp := 1 - side
	hands[side].erase(card)
	_retire_top()
	top_card = card
	if card.is_wild():
		card.chosen_color = chosen if chosen >= 0 else CardFactory.random_color()
	active_color = card.effective_color()
	stuck_in_row = 0

	var res := {
		"side": side, "card": card, "draw_target": opp, "draws": [], "discarded": [],
		"extra_turn": false, "swapped": false, "heal": 0, "gold": 0, "hp_loss": 0,
		"texts": [], "blocked": false,
	}
	var penalty := 0
	match card.type:
		CardData.Type.SKIP:
			res.extra_turn = true
			res.texts.append("SKIP!")
		CardData.Type.REVERSE:
			res.extra_turn = true
			res.texts.append("REVERSE!")
			if side == PLAYER and has_charm("mirror_shard"):
				penalty += 1
		CardData.Type.DRAW_TWO:
			res.extra_turn = true
			penalty += 2
			if side == ENEMY and has_ability("spiky"):
				penalty += 1
		CardData.Type.WILD_DRAW_FOUR:
			res.extra_turn = true
			penalty += 4
		CardData.Type.DISCARD_ALL:
			var same: Array = hands[side].filter(func(c): return c.card_color == card.card_color)
			for c in same:
				hands[side].erase(c)
				discards[c.owner_side].append(c)
			res.discarded = same
			res.texts.append("DISCARD ALL!")
		CardData.Type.WILD_SWAP:
			if not hands[side].is_empty():
				var tmp: Array = hands[side]
				hands[side] = hands[opp]
				hands[opp] = tmp
				res.swapped = true
				res.texts.append("SWAP!")

	if side == PLAYER:
		if card.is_wild() and has_charm("prism"):
			penalty += 1
		if card.is_draw_card() and has_charm("vampire_fang"):
			res.heal += 2
		if has_charm("pickpocket"):
			res.gold += 1
		if has_ability("thorns") and card.is_action():
			res.hp_loss += 1
		match card.enchant:
			CardData.Enchant.GILDED:
				res.gold += 3
			CardData.Enchant.HEALING:
				res.heal += 2
	if card.enchant == CardData.Enchant.BARBED:
		penalty += 1

	if penalty > 0 and opp == PLAYER and gloves_ready:
		gloves_ready = false
		penalty = max(0, penalty - 2)
		res.blocked = true
	if penalty > 0:
		res.draws = draw_many(opp, penalty)
		res.texts.append("+%d" % penalty)
	extra_turn = res.extra_turn
	return res

# penalize
# DESCRIPTION: Forced draws outside of card effects (e.g. getting caught without calling DOS).
func penalize(side: int, amount: int) -> Array:
	return draw_many(side, amount)

func note_stuck() -> void:
	stuck_in_row += 1

func end_turn() -> void:
	if extra_turn:
		extra_turn = false
	else:
		current = 1 - current

# winner
# DESCRIPTION: Returns the winning side, or -1 while the battle continues. A long stalemate goes to the smaller hand.
func winner() -> int:
	if hands[PLAYER].is_empty():
		return PLAYER
	if hands[ENEMY].is_empty():
		return ENEMY
	if stuck_in_row >= 4:
		return PLAYER if hands[PLAYER].size() < hands[ENEMY].size() else ENEMY
	return -1

# total_cards
# DESCRIPTION: Debug helper used by the simulation test to verify no cards are lost or duplicated.
func total_cards() -> int:
	var n := 1 if top_card != null else 0
	for side in 2:
		n += hands[side].size() + draw_piles[side].size() + discards[side].size()
	return n
