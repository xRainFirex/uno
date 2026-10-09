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
	var trick_events := [_painter(), _frozen_lake(), _secret_santa(), _dice_table(), _clockmaker(), _jester()]
	events.append_array(trick_events)
	# Trickster's Pact makes the trick-card events twice as likely.
	if RunState.has_charm("tricksters_pact"):
		events.append_array(trick_events)
	return events.pick_random()

# ---------- Helpers shared by the trick-card events ----------

func _rare_trick() -> CardData:
	var t: int = [CardData.Type.DOUBLE_DOWN, CardData.Type.WILD_CHAIN, CardData.Type.WILD_MIRROR, CardData.Type.WILD_SWAP].pick_random()
	if t == CardData.Type.DOUBLE_DOWN:
		return CardFactory.action(CardFactory.random_color(), t)
	return CardFactory.wild(t)

func _gain(card: CardData) -> String:
	RunState.add_card(card)
	Sfx.play("power")
	return card.title()

func _cards_where(test: Callable) -> Array:
	return RunState.deck.filter(test)

# _pick_card
# DESCRIPTION: Opens the deck picker over a filtered list. Returns null if cancelled.
func _pick_card(title_text: String, cards: Array, subtitle: String) -> CardData:
	var viewer: DeckViewer = router.open_deck(title_text, cards, true, subtitle)
	return await viewer.closed

# ---------- Trick-card events ----------

func _painter() -> Dictionary:
	var plain := func(c): return c.type == CardData.Type.NUMBER and not c.is_dual()
	return {
		"title": "THE TWO-TONE PAINTER", "icon": "mask", "color": Color(0.95, 0.45, 0.65),
		"text": "Paint-spattered and humming, an artist eyes your deck. \"Such dull, single colours. Let me fix that.\"",
		"choices": [
			{"label": "Repaint a number card  (it becomes dual-colour)", "enabled": not _cards_where(plain).is_empty(), "action": func():
				var card := await _pick_card("REPAINT A CARD", _cards_where(plain), "Choose a number card to give a second colour.")
				if card == null:
					return ""
				var others := CardFactory.COLORS.filter(func(c): return c != card.card_color)
				card.second_color = others.pick_random()
				RunState.changed.emit()
				Sfx.play("power")
				return "A few bold strokes later, it's now %s." % card.title()},
			{"label": "Buy a finished set  (30 gold: 2 random dual-colour cards)", "enabled": RunState.gold >= 30, "action": func():
				RunState.spend_gold(30)
				var a := _gain(CardFactory.dual(randi_range(0, 9)))
				var b := _gain(CardFactory.dual(randi_range(0, 9)))
				return "Still wet, but they'll do: %s and %s." % [a, b]},
			{"label": "Leave", "action": _leave},
		],
	}

func _frozen_lake() -> Dictionary:
	return {
		"title": "THE FROZEN LAKE", "icon": "snowflake", "color": Color(0.55, 0.85, 1.0),
		"text": "The ice groans beneath your feet. Below the surface, something glints: a deck, frozen solid.",
		"choices": [
			{"label": "Smash the ice and dive  (lose 8 HP, gain 2 Freeze cards)", "action": func():
				RunState.take_damage(8)
				var a := _gain(CardFactory.action(CardFactory.random_color(), CardData.Type.FREEZE))
				var b := _gain(CardFactory.action(CardFactory.random_color(), CardData.Type.FREEZE))
				return "Numb to the bone, you haul out %s and %s." % [a, b]},
			{"label": "Skate out carefully  (50%: a Freeze card, 50%: fall in and lose 6 HP)", "action": func():
				if randf() < 0.5:
					return "You glide out and chip it free: %s." % _gain(CardFactory.action(CardFactory.random_color(), CardData.Type.FREEZE))
				RunState.take_damage(6)
				Sfx.play("hurt")
				return "CRACK. You go straight through. Nothing to show for it but chattering teeth."},
			{"label": "Leave", "action": _leave},
		],
	}

func _secret_santa() -> Dictionary:
	return {
		"title": "SECRET SANTA", "icon": "gift", "color": Color(0.9, 0.4, 0.6),
		"text": "A jolly stranger in a red hat blocks the road. \"Gift exchange! Rules are rules. Everyone gives, everyone gets.\"",
		"choices": [
			{"label": "Exchange a card  (give one of your choice, get a random rare trick card)", "enabled": RunState.deck.size() > 8, "action": func():
				var card := await _pick_card("GIVE A CARD", RunState.deck, "Choose the card you'll wrap up.")
				if card == null:
					return ""
				RunState.remove_card(card)
				return "You hand over %s and unwrap... %s!" % [card.title(), _gain(_rare_trick())]},
			{"label": "Take a free present  (gain a Gift card and 15 gold)", "action": func():
				RunState.gain_gold(15)
				return "Inside: 15 gold and %s. How fitting." % _gain(CardFactory.action(CardFactory.random_color(), CardData.Type.GIFT))},
			{"label": "Leave", "action": _leave},
		],
	}

func _dice_table() -> Dictionary:
	return {
		"title": "THE DOUBLE-OR-NOTHING TABLE", "icon": "dice", "color": Color(0.95, 0.35, 0.3),
		"text": "A croupier rattles a pair of red dice. \"Everything doubles here, friend. Or it doesn't.\"",
		"choices": [
			{"label": "Bet a card  (50%: it doubles, 50%: it's gone)", "enabled": RunState.deck.size() > 8, "action": func():
				var card := await _pick_card("BET A CARD", RunState.deck, "Choose the card to put on the table.")
				if card == null:
					return ""
				if randf() < 0.5:
					RunState.add_card(card)
					Sfx.play("coin")
					return "Doubles! You walk away with two copies of %s." % card.title()
				RunState.remove_card(card)
				Sfx.play("lose")
				return "Snake eyes. The croupier sweeps %s off the table." % card.title()},
			{"label": "Buy a lucky roll  (25 gold: 60% chance of a Double Down card)", "enabled": RunState.gold >= 25, "action": func():
				RunState.spend_gold(25)
				if randf() < 0.6:
					return "The dice come up sixes: %s." % _gain(CardFactory.action(CardFactory.random_color(), CardData.Type.DOUBLE_DOWN))
				Sfx.play("lose")
				return "Ones. The croupier pockets your gold with a shrug."},
			{"label": "Leave", "action": _leave},
		],
	}

func _clockmaker() -> Dictionary:
	var skips := func(c): return c.type == CardData.Type.SKIP
	return {
		"title": "THE CLOCKMAKER", "icon": "clock", "color": Color(0.85, 0.7, 0.4),
		"text": "Gears whirr in an impossible little shop. \"Time is the only currency that matters,\" says the clockmaker, without looking up.",
		"choices": [
			{"label": "Tune a Skip  (a Skip in your deck becomes a Freeze)", "enabled": not _cards_where(skips).is_empty(), "action": func():
				var card := await _pick_card("TUNE A SKIP", _cards_where(skips), "Choose a Skip to upgrade into a Freeze.")
				if card == null:
					return ""
				card.type = CardData.Type.FREEZE
				RunState.changed.emit()
				Sfx.play("power")
				return "Tick, tock. Your card is now %s." % card.title()},
			{"label": "Trade years for time  (lose 6 max HP, gain a Wild Chain)", "enabled": RunState.max_hp > 12, "action": func():
				RunState.change_max_hp(-6)
				return "You feel older. In your hand: %s." % _gain(CardFactory.wild(CardData.Type.WILD_CHAIN))},
			{"label": "Leave", "action": _leave},
		],
	}

func _jester() -> Dictionary:
	# Three face-down prizes in a random order: a rare trick card, some gold, or a nasty pinch.
	var prizes := ["trick", "gold", "hurt"]
	prizes.shuffle()
	var choices: Array = []
	for i in 3:
		var prize: String = prizes[i]
		choices.append({"label": ["Pick the left card", "Pick the middle card", "Pick the right card"][i], "action": func():
			match prize:
				"trick":
					return "The jester bows. \"A winner!\" You receive %s." % _gain(_rare_trick())
				"gold":
					RunState.gain_gold(30)
					Sfx.play("coin")
					return "It's a gold card. Literally. +30 gold."
			RunState.take_damage(5)
			Sfx.play("hurt")
			return "The card bites you. The jester cackles. (-5 HP)"})
	choices.append({"label": "Leave", "action": _leave})
	return {
		"title": "THE JESTER'S GAME", "icon": "joker", "color": Color(0.6, 0.85, 0.35),
		"text": "A jester fans three face-down cards with a grin far too wide. \"One treasure, one trinket, one trick. Pick, pick, pick!\"",
		"choices": choices,
	}

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
		"title": "SHRINE OF THE ELEMENTS", "icon": "diamond", "color": Color(0.85, 0.85, 0.95),
		"text": "Four candles burn with ember, tide, moss and dusk before a silent altar.",
		"choices": [
			{"label": "Offer your blood  (lose 6 max HP, gain a random charm)", "enabled": not Charms.random_unowned(RunState.charms, 1).is_empty(), "action": func():
				var id: String = Charms.random_unowned(RunState.charms, 1)[0]
				RunState.change_max_hp(-6)
				RunState.add_charm(id)
				Sfx.play("power")
				return "The candles flicker. You receive %s: %s" % [Charms.get_def(id).name, Charms.get_def(id).desc]},
			{"label": "Pray  (add a random rare card to your deck)", "action": func():
				var card := CardFactory.card_of_rarity(CardData.Rarity.RARE, RunState.has_charm("tricksters_pact"))
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
				var card := CardFactory.card_of_rarity(CardData.Rarity.RARE, RunState.has_charm("tricksters_pact"))
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
				var card := CardFactory.card_of_rarity(CardData.Rarity.UNCOMMON, RunState.has_charm("tricksters_pact"))
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
			{"label": "Step through the glass  (lose 6 HP, gain a Wild Mirror)", "action": func():
				RunState.take_damage(6)
				return "The world flips. You come back holding %s." % _gain(CardFactory.wild(CardData.Type.WILD_MIRROR))},
			{"label": "Smash the mirror  (+30 gold, lose 4 HP)", "action": func():
				RunState.gain_gold(30)
				RunState.take_damage(4)
				Sfx.play("hurt")
				return "Shards everywhere. Behind the glass, a small stash of coins."},
			{"label": "Leave", "action": _leave},
		],
	}
