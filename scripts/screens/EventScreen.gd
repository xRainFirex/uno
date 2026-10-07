# ==========================================
# FILE: EventScreen.gd
# DESCRIPTION: Random narrative events with risky choices.
# VERSION: v0.100
# ==========================================
class_name EventScreen
extends Control

var router: Node
var _text: Label
var _choices: VBoxContainer
var _event: Dictionary

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_event = _roll_event()

	var panel := UIKit.panel(26)
	panel.custom_minimum_size = Vector2(860, 0)
	var center := UIKit.centered(panel)
	center.offset_top = Hud.HEIGHT
	add_child(center)
	var col := UIKit.vbox(16)
	panel.add_child(col)
	var icon := Glyph.new(_event.icon, _event.color, 96)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	col.add_child(UIKit.title(_event.title, 52, _event.color.lightened(0.2)))
	_text = UIKit.label(_event.text, 21, UIKit.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 780
	col.add_child(_text)
	col.add_child(UIKit.spacer(0, 6))
	_choices = UIKit.vbox(10)
	col.add_child(_choices)
	for choice in _event.choices:
		var b := UIKit.button(choice.label, "", Vector2(0, 56))
		b.disabled = not choice.get("enabled", true)
		b.pressed.connect(_on_choice.bind(choice))
		_choices.add_child(b)

func _on_choice(choice: Dictionary) -> void:
	for b in _choices.get_children():
		(b as Button).disabled = true
	var result: String = await choice.action.call()
	if result == "":
		# Cancelled a sub-choice (e.g. closed the card picker); re-enable options.
		for i in _choices.get_child_count():
			(_choices.get_child(i) as Button).disabled = not _event.choices[i].get("enabled", true)
		return
	_text.text = result
	for b in _choices.get_children():
		b.queue_free()
	var cont := UIKit.button("CONTINUE", "AccentButton", Vector2(0, 56))
	cont.pressed.connect(func():
		if RunState.is_dead():
			router.show_end(false)
		else:
			router.show_map())
	_choices.add_child(cont)

func _leave() -> String:
	return "You decide it isn't worth the risk, and move on."

func _roll_event() -> Dictionary:
	var events := [_fountain(), _card_shark(), _library(), _shrine(), _dealer(), _mirror()]
	return events.pick_random()

func _fountain() -> Dictionary:
	return {
		"title": "THE WISHING FOUNTAIN", "icon": "coin", "color": UIKit.GOLD,
		"text": "Coins glitter at the bottom of an old fountain. A sign reads: \"Take what you need. Pay what you owe.\"",
		"choices": [
			{"label": "Grab the coins  (+45 gold, lose 7 HP)", "action": func():
				RunState.gain_gold(45)
				RunState.take_damage(7)
				Sfx.play("coin")
				return "Your hands come back full of gold and painfully numb."},
			{"label": "Drink deeply  (heal 15 HP)", "action": func():
				RunState.heal(15)
				Sfx.play("heal")
				return "The water is cold and sweet. You feel restored."},
			{"label": "Leave", "action": _leave},
		],
	}

func _card_shark() -> Dictionary:
	return {
		"title": "THE CARD SHARK", "icon": "cards", "color": Color(0.45, 0.8, 0.95),
		"text": "A slick stranger fans a deck with one hand. \"Double or nothing, friend? Fifty-fifty. Honest.\"",
		"choices": [
			{"label": "Bet 30 gold", "enabled": RunState.gold >= 30, "action": func(): return _gamble(30)},
			{"label": "Bet 60 gold", "enabled": RunState.gold >= 60, "action": func(): return _gamble(60)},
			{"label": "Walk away", "action": _leave},
		],
	}

func _gamble(amount: int) -> String:
	if randf() < 0.5:
		RunState.gain_gold(amount)
		Sfx.play("coin")
		return "The card flips... yours wins! You pocket %d gold." % amount
	RunState.spend_gold(amount)
	Sfx.play("lose")
	return "The card flips... the shark grins. You lose %d gold." % amount

func _library() -> Dictionary:
	return {
		"title": "THE FORGOTTEN LIBRARY", "icon": "question", "color": Color(0.62, 0.58, 1.0),
		"text": "Dusty tomes describe strategies long forgotten. One book hums with a strange energy.",
		"choices": [
			{"label": "Study the rules  (remove a card from your deck)", "enabled": RunState.deck.size() > 8, "action": func():
				var viewer: DeckViewer = router.open_deck("REMOVE A CARD", RunState.deck, true, "Choose a card to remove permanently.")
				var card: CardData = await viewer.closed
				if card == null:
					return ""
				RunState.remove_card(card)
				Sfx.play("power")
				return "You strike %s from your repertoire." % card.title()},
			{"label": "Read the humming book  (enchant a random card, lose 5 HP)", "action": func():
				var pool := RunState.deck.filter(func(c): return c.enchant == CardData.Enchant.NONE)
				RunState.take_damage(5)
				if pool.is_empty():
					return "The words burn your eyes, but there is nothing left to enchant."
				var card: CardData = pool.pick_random()
				card.enchant = randi_range(1, CardData.Enchant.size() - 1) as CardData.Enchant
				RunState.changed.emit()
				Sfx.play("power")
				return "The pages flare. Your card becomes %s." % card.title()},
			{"label": "Leave", "action": _leave},
		],
	}

func _shrine() -> Dictionary:
	return {
		"title": "SHRINE OF COLOURS", "icon": "diamond", "color": Color(0.85, 0.85, 0.95),
		"text": "Four candles burn red, blue, green and yellow before a silent altar.",
		"choices": [
			{"label": "Offer your blood  (lose 6 max HP, gain a random charm)", "enabled": not Charms.random_unowned(RunState.charms, 1).is_empty(), "action": func():
				var id: String = Charms.random_unowned(RunState.charms, 1)[0]
				RunState.change_max_hp(-6)
				RunState.add_charm(id)
				Sfx.play("power")
				return "The candles flicker. You receive %s: %s" % [Charms.get_def(id).name, Charms.get_def(id).desc]},
			{"label": "Pray  (add a random rare card to your deck)", "action": func():
				var card := CardFactory.card_of_rarity(CardData.Rarity.RARE)
				RunState.add_card(card)
				Sfx.play("power")
				return "A card materialises on the altar: %s." % card.title()},
			{"label": "Leave", "action": _leave},
		],
	}

func _dealer() -> Dictionary:
	return {
		"title": "THE WANDERING DEALER", "icon": "bag", "color": Color(0.42, 0.85, 0.55),
		"text": "A hooded figure opens a velvet case. \"One mystery card. Rare quality. Forty gold.\"",
		"choices": [
			{"label": "Buy the mystery card  (40 gold)", "enabled": RunState.gold >= 40, "action": func():
				RunState.spend_gold(40)
				var card := CardFactory.card_of_rarity(CardData.Rarity.RARE)
				if randf() < 0.5:
					card.enchant = randi_range(1, CardData.Enchant.size() - 1) as CardData.Enchant
				RunState.add_card(card)
				Sfx.play("coin")
				return "You unwrap it: %s." % card.title()},
			{"label": "Trade: give 2 random cards for 1 random action card", "enabled": RunState.deck.size() > 10, "action": func():
				var lost: Array = []
				for i in 2:
					var c: CardData = RunState.deck.pick_random()
					lost.append(c.title())
					RunState.remove_card(c)
				var card := CardFactory.card_of_rarity(CardData.Rarity.UNCOMMON)
				RunState.add_card(card)
				Sfx.play("power")
				return "You hand over %s and %s, and receive %s." % [lost[0], lost[1], card.title()]},
			{"label": "Leave", "action": _leave},
		],
	}

func _mirror() -> Dictionary:
	return {
		"title": "THE HALL OF MIRRORS", "icon": "eye", "color": Color(0.4, 0.6, 0.95),
		"text": "Your reflection holds a card you don't remember owning. It offers to trade places.",
		"choices": [
			{"label": "Duplicate a card in your deck", "action": func():
				var viewer: DeckViewer = router.open_deck("DUPLICATE A CARD", RunState.deck, true, "Choose a card to copy.")
				var card: CardData = await viewer.closed
				if card == null:
					return ""
				RunState.add_card(card)
				Sfx.play("power")
				return "The reflection hands you a perfect copy of %s." % card.title()},
			{"label": "Smash the mirror  (+30 gold, lose 4 HP)", "action": func():
				RunState.gain_gold(30)
				RunState.take_damage(4)
				Sfx.play("hurt")
				return "Shards everywhere. Behind the glass, a small stash of coins."},
			{"label": "Leave", "action": _leave},
		],
	}
