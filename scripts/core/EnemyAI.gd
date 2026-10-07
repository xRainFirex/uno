# ==========================================
# FILE: EnemyAI.gd
# DESCRIPTION: Opponent decision making. Styles: "random", "aggressive" and "smart".
# VERSION: v0.100
# ==========================================
class_name EnemyAI
extends RefCounted

# choose
# DESCRIPTION: Returns {"card": CardData, "color": int} or an empty dictionary when nothing is playable.
static func choose(state: BattleState, side: int, style: String) -> Dictionary:
	var playable: Array = state.playable_cards(side)
	if playable.is_empty():
		return {}
	var hand: Array = state.hands[side]
	var opp_count: int = state.hands[1 - side].size()
	var best: CardData = null
	if style == "random":
		best = playable.pick_random()
	else:
		var best_score := -INF
		for card in playable:
			var s := score(card, hand, opp_count, style, state.top_card)
			if s > best_score:
				best_score = s
				best = card
	return {"card": best, "color": color_for(hand, best)}

# score
# DESCRIPTION: Heuristic value of playing a card right now.
static func score(card: CardData, hand: Array, opp_count: int, style: String, top: CardData = null) -> float:
	var aggro := 2.0 if style == "aggressive" else 1.0
	var s := 0.0
	var same_color := 0
	for c in hand:
		if c != card and not c.is_wild() and (c.has_color(card.card_color) or (card.is_dual() and c.has_color(card.second_color))):
			same_color += 1
	match card.type:
		CardData.Type.NUMBER:
			s += card.value * 0.3 + same_color * 1.2
		CardData.Type.SKIP, CardData.Type.REVERSE:
			s += 4.0 * aggro + same_color
		CardData.Type.DRAW_TWO:
			s += 3.0 * aggro + same_color + (8.0 if opp_count <= 3 else 0.0)
		CardData.Type.DISCARD_ALL:
			s += 3.0 + same_color * 3.0
		CardData.Type.WILD:
			s += -8.0 + (12.0 if hand.size() <= 2 else 0.0) + (10.0 if hand.size() >= 8 else 0.0)
		CardData.Type.WILD_DRAW_FOUR:
			s += -4.0 * (1.0 / aggro) + (12.0 if opp_count <= 3 else 0.0) + (10.0 if hand.size() >= 8 else 0.0)
		CardData.Type.WILD_SWAP:
			# Only worth it for a big swing; small swaps just ping-pong hands back and forth.
			s += 25.0 if opp_count < hand.size() - 4 else -40.0
		CardData.Type.DOUBLE_DOWN:
			s += 2.0 * aggro + minf(opp_count, CardData.DOUBLE_DOWN_CAP) * 1.5
		CardData.Type.FREEZE:
			s += 6.0 * aggro + same_color
		CardData.Type.GIFT:
			s += 3.0 + (6.0 if hand.size() >= 4 else 0.0)
		CardData.Type.WILD_CHAIN:
			s += -3.0 + (10.0 if hand.size() <= 3 or hand.size() >= 8 else 0.0)
		CardData.Type.WILD_MIRROR:
			var copies_action := top != null and top.type != CardData.Type.NUMBER and top.type != CardData.Type.WILD
			s += 8.0 if copies_action else -8.0
	var noise := 3.0 if style == "aggressive" else 1.0
	return s + randf() * noise

# color_for
# DESCRIPTION: Colour to declare for a card: any colour for wilds, one of its two colours for dual cards.
static func color_for(hand: Array, playing: CardData) -> int:
	if playing != null and playing.is_dual():
		var a := _count_color(hand, playing, playing.card_color)
		var b := _count_color(hand, playing, playing.second_color)
		return playing.card_color if a >= b else playing.second_color
	return best_color(hand, playing)

static func _count_color(hand: Array, playing: CardData, color: int) -> int:
	var n := 0
	for c in hand:
		if c != playing and c.has_color(color):
			n += 1
	return n

# best_color
# DESCRIPTION: Picks the colour the AI holds the most of (ignoring the card being played).
static func best_color(hand: Array, playing: CardData) -> int:
	var counts := [0, 0, 0, 0]
	for c in hand:
		if c != playing and not c.is_wild():
			for col in c.colors():
				counts[col] += 1
	var best := CardFactory.random_color()
	var best_n := 0
	for i in 4:
		if counts[i] > best_n:
			best_n = counts[i]
			best = i
	return best
