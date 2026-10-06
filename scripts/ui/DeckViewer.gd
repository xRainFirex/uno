# ==========================================
# FILE: DeckViewer.gd
# DESCRIPTION: Modal grid of cards. Used to browse the deck, or to pick a card (remove / enchant).
#              Emits `closed(card)` with the chosen card, or null if dismissed.
# VERSION: v0.100
# ==========================================
class_name DeckViewer
extends Control

signal closed(card: CardData)

var _title := ""
var _subtitle := ""
var _cards: Array = []
var _selectable := false
var _cancellable := true

func setup(title_text: String, cards: Array, selectable: bool = false, subtitle: String = "", cancellable: bool = true) -> DeckViewer:
	_title = title_text
	_cards = cards.duplicate()
	_cards.sort_custom(func(a, b): return a.sort_key() < b.sort_key())
	_selectable = selectable
	_subtitle = subtitle
	_cancellable = cancellable
	return self

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.dimmer(0.8))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 120)
	margin.add_theme_constant_override("margin_top", 70)
	margin.add_theme_constant_override("margin_bottom", 50)
	add_child(margin)

	var panel := UIKit.panel(24)
	margin.add_child(panel)
	var col := UIKit.vbox(14)
	panel.add_child(col)

	col.add_child(UIKit.title(_title, 44, UIKit.GOLD))
	var sub := UIKit.label(_subtitle if _subtitle != "" else _summary(), 19, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	center.add_child(grid)

	for card in _cards:
		var holder := Control.new()
		holder.custom_minimum_size = CardView.CARD_SIZE + Vector2(0, 30)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(holder)
		var v := CardView.new(card)
		v.position = Vector2(0, 26)
		v.hover_lift = 14.0 if _selectable else 0.0
		v.interactive = true
		if _selectable:
			v.clicked.connect(func(view: CardView): _finish(view.data))
		holder.add_child(v)

	if _cancellable:
		var close := UIKit.button("CANCEL" if _selectable else "CLOSE", "", Vector2(220, 0))
		close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		close.pressed.connect(func(): _finish(null))
		col.add_child(close)

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)

func _summary() -> String:
	var counts := {"num": 0, "act": 0, "wild": 0}
	for c in _cards:
		if c.is_wild():
			counts.wild += 1
		elif c.is_action():
			counts.act += 1
		else:
			counts.num += 1
	return "%d cards  ·  %d numbers  ·  %d actions  ·  %d wilds" % [_cards.size(), counts.num, counts.act, counts.wild]

func _unhandled_input(event: InputEvent) -> void:
	if _cancellable and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(null)

func _finish(card: CardData) -> void:
	if is_queued_for_deletion():
		return
	closed.emit(card)
	queue_free()
