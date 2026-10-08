# ==========================================
# FILE: ShopScreen.gd
# DESCRIPTION: Buy cards and charms, pay to remove a card, or patch yourself up.
# VERSION: v0.100
# ==========================================
class_name ShopScreen
extends Control

const HEAL_AMOUNT := 12
const HEAL_PRICE := 30

var router: Node
var _price_labels: Array = []   # [Label, price, sold_flag_getter]
var _remove_button: Button
var _heal_button: Button
var _heal_used := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mult := RunState.price_multiplier()

	var col := UIKit.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = Hud.HEIGHT
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	col.add_child(UIKit.title("THE CURIO SHOP", 64, UIKit.GOLD))
	var keeper: String = ["\"Everything's for sale. Even luck.\"", "\"No refunds. No questions.\"", "\"Fresh decks, barely marked.\""].pick_random()
	col.add_child(UIKit.label(keeper, 20, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	if mult < 1.0:
		col.add_child(UIKit.label("Deep Pockets: 25% off everything", 17, UIKit.SUCCESS, true, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.spacer(0, 10))

	var cards_row := UIKit.hbox(30)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(cards_row)
	var tricks := RunState.has_charm("tricksters_pact")
	var stock: Array[CardData] = CardFactory.reward_choices(3, RunState.act, 0.0, tricks)
	stock.append(CardFactory.card_of_rarity(CardData.Rarity.UNCOMMON, tricks))
	stock.append(CardFactory.card_of_rarity(CardData.Rarity.RARE, tricks))
	for card in stock:
		var price := int(CardFactory.price(card) * mult)
		var holder := UIKit.vbox(8)
		var box := Control.new()
		box.custom_minimum_size = CardView.CARD_SIZE + Vector2(0, 30)
		holder.add_child(box)
		var v := CardView.new(card)
		v.position = Vector2(0, 28)
		v.interactive = true
		box.add_child(v)
		var tag := _price_tag(price)
		holder.add_child(tag)
		cards_row.add_child(holder)
		v.clicked.connect(func(view: CardView):
			if view.get_meta("sold", false):
				return
			if not RunState.spend_gold(price):
				_deny(view)
				return
			RunState.add_card(view.data)
			Sfx.play("coin")
			view.set_meta("sold", true)
			view.interactive = false
			view.hovered = false
			_mark_sold(view, tag))
		_price_labels.append([tag, price, v])

	col.add_child(UIKit.spacer(0, 6))
	var lower := UIKit.hbox(26)
	lower.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(lower)
	for id in Charms.random_unowned(RunState.charms, 2):
		var price := int(Charms.price(id) * mult)
		var holder := UIKit.vbox(8)
		var b := RewardScreen.charm_button(id)
		holder.add_child(b)
		var tag := _price_tag(price)
		holder.add_child(tag)
		lower.add_child(holder)
		b.pressed.connect(func():
			if b.get_meta("sold", false):
				return
			if not RunState.spend_gold(price):
				_deny(b)
				return
			RunState.add_charm(id)
			Sfx.play("coin")
			b.set_meta("sold", true)
			b.disabled = true
			_mark_sold(b, tag))
		_price_labels.append([tag, price, b])

	var services := UIKit.vbox(12)
	services.alignment = BoxContainer.ALIGNMENT_CENTER
	services.custom_minimum_size.x = 300
	lower.add_child(services)
	services.add_child(UIKit.label("SERVICES", 18, UIKit.TEXT_MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	_remove_button = UIKit.button("", "", Vector2(0, 64))
	_remove_button.tooltip_text = "Thin your deck so your best cards show up more often."
	_remove_button.pressed.connect(_on_remove)
	services.add_child(_remove_button)
	_heal_button = UIKit.button("", "", Vector2(0, 64))
	_heal_button.pressed.connect(_on_heal)
	services.add_child(_heal_button)

	col.add_child(UIKit.spacer(0, 16))
	var leave := UIKit.button("LEAVE SHOP", "AccentButton", Vector2(260, 60))
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(func(): router.show_map())
	col.add_child(leave)

	RunState.changed.connect(_refresh)
	_refresh()

func _price_tag(price: int) -> HBoxContainer:
	var row := UIKit.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(Glyph.new("coin", UIKit.GOLD, 24))
	var l := UIKit.label(str(price), 22, UIKit.GOLD, true)
	l.name = "Price"
	row.add_child(l)
	return row

func _mark_sold(node: Control, tag: HBoxContainer) -> void:
	create_tween().tween_property(node, "modulate:a", 0.25, 0.25)
	var l := tag.get_node("Price") as Label
	l.text = "SOLD"
	l.add_theme_color_override("font_color", UIKit.TEXT_MUTED)

func _deny(node: Control) -> void:
	Sfx.play("error")
	if node is CardView:
		(node as CardView).shake()
	var tw := create_tween()
	tw.tween_property(node, "modulate", Color(1, 0.5, 0.5), 0.08)
	tw.tween_property(node, "modulate", Color.WHITE, 0.2)

func _removal_price() -> int:
	return int(RunState.removal_cost * RunState.price_multiplier())

func _refresh() -> void:
	if not is_inside_tree():
		return
	for entry in _price_labels:
		var tag: HBoxContainer = entry[0]
		var l := tag.get_node("Price") as Label
		if l.text != "SOLD":
			l.add_theme_color_override("font_color", UIKit.GOLD if RunState.gold >= entry[1] else UIKit.DANGER)
	_remove_button.text = "REMOVE A CARD   %dg" % _removal_price()
	_remove_button.disabled = RunState.gold < _removal_price() or RunState.deck.size() <= 8
	_heal_button.text = "BANDAGES  +%d HP   %dg" % [HEAL_AMOUNT, int(HEAL_PRICE * RunState.price_multiplier())]
	_heal_button.disabled = _heal_used or RunState.gold < int(HEAL_PRICE * RunState.price_multiplier()) or RunState.hp >= RunState.max_hp

func _on_remove() -> void:
	var viewer: DeckViewer = router.open_deck("REMOVE A CARD", RunState.deck, true, "Choose a card to remove permanently (%d gold)." % _removal_price())
	var card: CardData = await viewer.closed
	if card == null or not RunState.spend_gold(_removal_price()):
		return
	RunState.remove_card(card)
	RunState.removal_cost += 25
	Sfx.play("coin")
	_refresh()

func _on_heal() -> void:
	if RunState.spend_gold(int(HEAL_PRICE * RunState.price_multiplier())):
		_heal_used = true
		RunState.heal(HEAL_AMOUNT)
		Sfx.play("heal")
		_refresh()
