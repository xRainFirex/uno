# ==========================================
# FILE: Main.gd
# DESCRIPTION: Orchestrates UI, turns, effects, Reward Phase, and the redesigned View Deck modal.
# VERSION: v0.030
# LAST EDITED: v0.030
# ==========================================
extends Control

@onready var player_hand_container = $UI/PlayerHand
@onready var ai_hand_container = $UI/AIHand
@onready var discard_container = $UI/DiscardPile/CardContainer
@onready var game_stage = $GameStage
@onready var deck_manager = $UnoDeck
@onready var color_picker = $UI/ColorPicker
@onready var player_deck_label = $UI/DeckInfo/PlayerDeckCount
@onready var ai_deck_label = $UI/DeckInfo/AIDeckCount
@onready var ai_name_label = $UI/AIName
@onready var game_over_modal = $UI/GameOver
@onready var reward_modal = $UI/RewardPhase
@onready var reward_container = $UI/RewardPhase/CardOptions
@onready var turn_indicator = $UI/TurnIndicator/Label

# View Deck UI references (Redesigned Structure)
@onready var view_deck_modal = $UI/ViewDeckModal
@onready var view_deck_grid = $UI/ViewDeckModal/Margin/VBox/Scroll/Grid

var card_scene = preload("res://Card.tscn")
var is_player_turn: bool = true
var is_picking_color: bool = false

# 9. _ready
# DESCRIPTION: Entry point for the main game scene. Connects all UI signals programmatically.
# LAST EDITED: v0.030
func _ready():
	color_picker.hide()
	game_over_modal.hide()
	reward_modal.hide()
	view_deck_modal.hide()
	
	game_stage.start_game()
	ai_name_label.text = "Opponent: " + game_stage.ai_name
	
	# Programmatic signal connections for Color Picker
	$UI/ColorPicker/Grid/Red.pressed.connect(_on_color_selected.bind(0))
	$UI/ColorPicker/Grid/Blue.pressed.connect(_on_color_selected.bind(1))
	$UI/ColorPicker/Grid/Green.pressed.connect(_on_color_selected.bind(2))
	$UI/ColorPicker/Grid/Yellow.pressed.connect(_on_color_selected.bind(3))
	
	# View Deck connections
	$UI/DeckInfo/ViewDeckButton.pressed.connect(_on_view_deck_pressed)
	$UI/ViewDeckModal/Margin/VBox/CloseButton.pressed.connect(func(): view_deck_modal.hide())
	$UI/ViewDeckModal/Margin/VBox/CloseButton.text = "Close"
	
	# Game Over connections
	$UI/GameOver/Buttons/Restart.pressed.connect(_on_restart_pressed)
	$UI/GameOver/Buttons/Quit.pressed.connect(_on_quit_pressed)
	
	render_player_hand()
	render_ai_hand()
	update_discard_visual()
	update_deck_counts()
	update_turn_indicator()

# 10. render_player_hand
# DESCRIPTION: Clears and repopulates the HBoxContainer with the player's current hand.
# LAST EDITED: v0.015
func render_player_hand():
	for child in player_hand_container.get_children():
		child.queue_free()
	for card_data in game_stage.player_hand:
		var card_instance = card_scene.instantiate()
		player_hand_container.add_child(card_instance)
		if card_instance.has_signal("card_selected"):
			card_instance.data = card_data
			card_instance.update_visuals(false)
			card_instance.card_selected.connect(_on_card_played)

# 11. update_discard_visual
# DESCRIPTION: Updates the visual representation of the top card on the discard pile.
# LAST EDITED: v0.015
func update_discard_visual():
	for child in discard_container.get_children():
		child.queue_free()
	var card_instance = card_scene.instantiate()
	discard_container.add_child(card_instance)
	if card_instance.has_signal("card_selected"):
		card_instance.data = game_stage.current_card
		card_instance.update_visuals(false)
		card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE

# 12. _on_card_played
# DESCRIPTION: Logic for when a player selects a card to play.
# LAST EDITED: v0.030
func _on_card_played(card_node):
	if not is_player_turn or is_picking_color: return
	if game_stage.is_card_playable(card_node.data):
		var played_data = card_node.data
		game_stage.player_discard.append(game_stage.current_card)
		game_stage.current_card = played_data
		game_stage.player_hand.erase(played_data)
		render_player_hand()
		update_discard_visual()
		
		if game_stage.player_hand.is_empty():
			show_reward_phase()
			return
		
		var is_skip = (played_data.type == xCardData.Type.SKIP or played_data.type == xCardData.Type.REVERSE)
		if played_data.card_color == xCardData.CardColor.WILD:
			show_color_picker()
		else:
			handle_card_effects(played_data, false)
			if is_skip:
				is_player_turn = true
				update_turn_indicator(game_stage.ai_name.to_upper() + " SKIPPED A TURN - YOUR TURN")
			else:
				is_player_turn = false
				update_turn_indicator()
				await get_tree().create_timer(1.0).timeout
				execute_ai_turn()

# 13. _on_draw_button_pressed
# DESCRIPTION: Logic for player drawing a card from their own deck.
# LAST EDITED: v0.022
func _on_draw_button_pressed():
	if not is_player_turn or is_picking_color: return
	var new_card = game_stage.draw_player_card()
	if new_card:
		game_stage.player_hand.append(new_card)
		render_player_hand()
		update_deck_counts()
		is_player_turn = false
		update_turn_indicator()
		await get_tree().create_timer(1.0).timeout
		execute_ai_turn()

# 17. render_ai_hand
# DESCRIPTION: Renders AI card backs at the top of the screen.
# LAST EDITED: v0.015
func render_ai_hand():
	for child in ai_hand_container.get_children():
		child.queue_free()
	for card_data in game_stage.ai_hand:
		var card_instance = card_scene.instantiate()
		ai_hand_container.add_child(card_instance)
		if card_instance.has_signal("card_selected"):
			card_instance.data = card_data
			card_instance.update_visuals(true)

# 18. execute_ai_turn
# DESCRIPTION: Processes the AI's turn logic. Hand is rendered before win check to ensure visual emptyness.
# LAST EDITED: v0.030
func execute_ai_turn():
	var played_card = game_stage.process_ai_turn()
	if played_card:
		game_stage.ai_discard.append(game_stage.current_card)
		game_stage.current_card = played_card
		game_stage.ai_hand.erase(played_card)
		
		# Render hand immediately so it appears empty if AI wins
		render_ai_hand()
		update_discard_visual()
		
		if game_stage.ai_hand.is_empty():
			show_game_over("GAME OVER - " + game_stage.ai_name.to_upper() + " WINS")
			return
			
		var is_skip = (played_card.type == xCardData.Type.SKIP or played_card.type == xCardData.Type.REVERSE)
		if played_card.card_color == xCardData.CardColor.WILD:
			played_card.card_color = xCardData.CardColor.RED 
		
		handle_card_effects(played_card, true)
		if is_skip:
			update_turn_indicator("YOU SKIPPED A TURN - " + game_stage.ai_name.to_upper() + " TURN")
			await get_tree().create_timer(1.0).timeout
			execute_ai_turn()
			return
	else:
		var drawn = game_stage.draw_ai_card()
		if drawn:
			game_stage.ai_hand.append(drawn)
			update_turn_indicator(game_stage.ai_name.to_upper() + " DREW A CARD - YOUR TURN")
	
	render_ai_hand()
	update_discard_visual()
	update_deck_counts()
	is_player_turn = true
	if turn_indicator.text.contains("THINKING"):
		update_turn_indicator()

# 31. update_deck_counts
# DESCRIPTION: Updates the UI labels to show the current size of player and AI decks.
# LAST EDITED: v0.013
func update_deck_counts():
	player_deck_label.text = "YOUR DECK: " + str(game_stage.player_deck.size())
	ai_deck_label.text = game_stage.ai_name.to_upper() + "'S DECK: " + str(game_stage.ai_deck.size())

# 20. show_color_picker
# DESCRIPTION: Displays the Wild card colour selection modal.
# LAST EDITED: v0.023
func show_color_picker():
	is_picking_color = true
	color_picker.show()

# 21. _on_color_selected
# DESCRIPTION: Handles the colour choice for Wild cards and proceeds with turn logic.
# LAST EDITED: v0.023
func _on_color_selected(color_idx: int):
	var played_card = game_stage.current_card
	if played_card:
		played_card.card_color = color_idx as xCardData.CardColor
		
	color_picker.hide()
	is_picking_color = false
	update_discard_visual()
	handle_card_effects(played_card, false)
	is_player_turn = false
	update_turn_indicator()
	await get_tree().create_timer(1.0).timeout
	execute_ai_turn()

# 22. handle_card_effects
# DESCRIPTION: Processes pickups (Draw Two, Wild Draw Four) based on the played card.
# LAST EDITED: v0.030
func handle_card_effects(card: xCardData, is_player_target: bool):
	if card.type == xCardData.Type.DRAW_TWO:
		game_stage.apply_pickup(is_player_target, 2)
		if is_player_target:
			update_turn_indicator("YOU PICKED UP 2 - YOUR TURN")
	elif card.type == xCardData.Type.WILD_DRAW_FOUR:
		game_stage.apply_pickup(is_player_target, 4)
		if is_player_target:
			update_turn_indicator("YOU PICKED UP 4 - YOUR TURN")
	render_ai_hand()
	render_player_hand()
	update_deck_counts()

# 24. show_game_over
# DESCRIPTION: Displays the end-game modal for losses.
# LAST EDITED: v0.018
func show_game_over(title_text: String):
	game_over_modal.get_node("Title").text = title_text
	game_over_modal.show()
	is_player_turn = false

# 34. show_reward_phase
# DESCRIPTION: Presents the player with 3 card options after winning a round.
# LAST EDITED: v0.018
func show_reward_phase():
	for child in reward_container.get_children():
		child.queue_free()
	
	reward_modal.show()
	is_player_turn = false
	
	for i in range(3):
		var card_data = deck_manager.generate_random_reward_card()
		var card_instance = card_scene.instantiate()
		reward_container.add_child(card_instance)
		card_instance.data = card_data
		card_instance.update_visuals(false)
		card_instance.card_selected.connect(_on_reward_selected)

# 35. _on_reward_selected
# DESCRIPTION: Adds selected reward (x2) to the persistent deck and starts a new round.
# LAST EDITED: v0.018
func _on_reward_selected(card_node):
	game_stage.add_to_persistent_deck(card_node.data)
	reward_modal.hide()
	_on_restart_pressed()

# 25. _on_restart_pressed
# DESCRIPTION: Resets the game stage for a new round while preserving the persistent deck.
# LAST EDITED: v0.022
func _on_restart_pressed():
	game_over_modal.hide()
	is_picking_color = false
	game_stage.start_game()
	render_player_hand()
	render_ai_hand()
	update_discard_visual()
	update_deck_counts()
	is_player_turn = true
	update_turn_indicator()

# 26. _on_quit_pressed
# DESCRIPTION: Quits the application.
# LAST EDITED: v0.010
func _on_quit_pressed():
	get_tree().quit()

# 27. update_turn_indicator
# DESCRIPTION: Updates the status label text and colour based on turn state. Personalised with opponent name.
# LAST EDITED: v0.030
func update_turn_indicator(custom_text: String = ""):
	if custom_text != "":
		turn_indicator.text = custom_text
		turn_indicator.modulate = Color(1.0, 0.8, 0.2)
		return
	if is_player_turn:
		turn_indicator.text = "YOUR TURN"
		turn_indicator.modulate = Color(0.2, 0.8, 0.2)
	else:
		turn_indicator.text = game_stage.ai_name.to_upper() + " THINKING..."
		turn_indicator.modulate = Color(0.8, 0.2, 0.2)

# 36. _on_view_deck_pressed
# DESCRIPTION: Populates the redesigned View Deck modal. Uses natural sizing to prevent clipping.
# LAST EDITED: v0.029
func _on_view_deck_pressed():
	for child in view_deck_grid.get_children():
		child.queue_free()
		
	for card_data in game_stage.player_deck:
		var card_instance = card_scene.instantiate()
		view_deck_grid.add_child(card_instance)
		card_instance.data = card_data
		card_instance.update_visuals(false)
		
		# Set modal-specific visual overrides
		card_instance.custom_minimum_size = Vector2(140, 200) 
		card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	view_deck_modal.show()
