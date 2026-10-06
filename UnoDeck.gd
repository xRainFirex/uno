# ==========================================
# FILE: UnoDeck.gd
# DESCRIPTION: Manages the generation of specific deck types and reward cards for roguelike play.
# VERSION: v0.006
# LAST EDITED: v0.006
# ==========================================
extends Node

# 28. generate_starter_deck
# DESCRIPTION: Creates a 24-card starter deck with a balanced distribution of numbers and specials.
# LAST EDITED: v0.005
func generate_starter_deck() -> Array[xCardData]:
	var new_deck: Array[xCardData] = []
	var colors = [xCardData.CardColor.RED, xCardData.CardColor.BLUE, xCardData.CardColor.GREEN, xCardData.CardColor.YELLOW]
	
	for c in colors:
		for i in range(1, 5):
			new_deck.append(xCardData.new(c, xCardData.Type.NUMBER, i))
		
	new_deck.append(xCardData.new(xCardData.CardColor.RED, xCardData.Type.SKIP))
	new_deck.append(xCardData.new(xCardData.CardColor.BLUE, xCardData.Type.SKIP))
	new_deck.append(xCardData.new(xCardData.CardColor.GREEN, xCardData.Type.DRAW_TWO))
	new_deck.append(xCardData.new(xCardData.CardColor.YELLOW, xCardData.Type.DRAW_TWO))
	
	new_deck.append(xCardData.new(xCardData.CardColor.WILD, xCardData.Type.WILD))
	new_deck.append(xCardData.new(xCardData.CardColor.WILD, xCardData.Type.WILD))
	new_deck.append(xCardData.new(xCardData.CardColor.WILD, xCardData.Type.WILD_DRAW_FOUR))
	new_deck.append(xCardData.new(xCardData.CardColor.WILD, xCardData.Type.WILD_DRAW_FOUR))
	
	new_deck.shuffle()
	return new_deck

# 32. generate_random_reward_card
# DESCRIPTION: Generates a single random card to be used as a potential reward.
# LAST EDITED: v0.006
func generate_random_reward_card() -> xCardData:
	var roll = randf()
	var colors = [xCardData.CardColor.RED, xCardData.CardColor.BLUE, xCardData.CardColor.GREEN, xCardData.CardColor.YELLOW]
	
	if roll < 0.6: # 60% chance for a Number
		return xCardData.new(colors.pick_random(), xCardData.Type.NUMBER, randi_range(0, 9))
	elif roll < 0.85: # 25% chance for an Action
		var actions = [xCardData.Type.SKIP, xCardData.Type.REVERSE, xCardData.Type.DRAW_TWO]
		return xCardData.new(colors.pick_random(), actions.pick_random())
	else: # 15% chance for a Wild
		var wilds = [xCardData.Type.WILD, xCardData.Type.WILD_DRAW_FOUR]
		return xCardData.new(xCardData.CardColor.WILD, wilds.pick_random())
