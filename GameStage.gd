# ==========================================
# FILE: GameStage.gd
# DESCRIPTION: Core controller managing asymmetric decks, hands, and deck persistence across rounds.
# VERSION: v0.006
# LAST EDITED: v0.006
# ==========================================
extends Node

@onready var deck_manager = get_node("../UnoDeck")

var player_hand: Array[xCardData] = []
var player_deck: Array[xCardData] = []
var player_discard: Array[xCardData] = []
var persistent_player_deck: Array[xCardData] = []

var ai_hand: Array[xCardData] = []
var ai_deck: Array[xCardData] = []
var ai_discard: Array[xCardData] = []
var ai_name: String = "Paul"

var current_card: xCardData

# 5. start_game
# DESCRIPTION: Initializes separate starter decks and deals initial hands. Handles persistence.
# LAST EDITED: v0.006
func start_game():
	if persistent_player_deck.is_empty():
		persistent_player_deck = deck_manager.generate_starter_deck()
	
	player_deck = persistent_player_deck.duplicate()
	player_deck.shuffle()
	
	# Paul's deck resets to starter for now, or could scale later
	ai_deck = deck_manager.generate_starter_deck()
	
	player_hand.clear()
	ai_hand.clear()
	player_discard.clear()
	ai_discard.clear()
	
	for i in range(6):
		player_hand.append(draw_player_card())
		ai_hand.append(draw_ai_card())
	
	current_card = draw_player_card()
	while current_card.card_color == xCardData.CardColor.WILD:
		player_deck.push_front(current_card)
		current_card = draw_player_card()

# 29. draw_player_card
# DESCRIPTION: Pulls a card from the player's specific deck, reshuffling discard if needed.
# LAST EDITED: v0.005
func draw_player_card() -> xCardData:
	if player_deck.is_empty():
		if player_discard.is_empty(): return null
		player_deck = player_discard.duplicate()
		player_deck.shuffle()
		player_discard.clear()
	return player_deck.pop_back()

# 30. draw_ai_card
# DESCRIPTION: Pulls a card from the AI's specific deck, reshuffling discard if needed.
# LAST EDITED: v0.005
func draw_ai_card() -> xCardData:
	if ai_deck.is_empty():
		if ai_discard.is_empty(): return null
		ai_deck = ai_discard.duplicate()
		ai_deck.shuffle()
		ai_discard.clear()
	return ai_deck.pop_back()

# 6. is_card_playable
# DESCRIPTION: Standard Uno matching logic.
# LAST EDITED: v0.002
func is_card_playable(card: xCardData) -> bool:
	if card.card_color == xCardData.CardColor.WILD: return true
	if card.card_color == current_card.card_color: return true
	if card.type == current_card.type:
		if card.type == xCardData.Type.NUMBER:
			return card.value == current_card.value
		return true
	return false

# 16. process_ai_turn
# DESCRIPTION: AI move selection.
# LAST EDITED: v0.003
func process_ai_turn() -> xCardData:
	for card in ai_hand:
		if is_card_playable(card): return card
	return null

# 19. apply_pickup
# DESCRIPTION: Applies draw penalties using respective decks.
# LAST EDITED: v0.005
func apply_pickup(is_player_target: bool, amount: int):
	for i in range(amount):
		var drawn = draw_player_card() if is_player_target else draw_ai_card()
		if drawn:
			if is_player_target: player_hand.append(drawn)
			else: ai_hand.append(drawn)

# 33. add_to_persistent_deck
# DESCRIPTION: Permanently adds two copies of a card to the player's run deck.
# LAST EDITED: v0.006
func add_to_persistent_deck(card_template: xCardData):
	for i in range(2):
		persistent_player_deck.append(xCardData.new(card_template.card_color, card_template.type, card_template.value))
