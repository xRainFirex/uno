# ==========================================
# FILE: RewardScreen.gd
# DESCRIPTION: Post-battle / treasure rewards: pick one of several cards and/or charms.
#              params: title, subtitle, gold, cards (count), card_bonus, charms (Array of ids), boss
# VERSION: v0.100
# ==========================================
class_name RewardScreen
extends Control

var router: Node
var params: Dictionary = {}
var _card_views: Array[CardView] = []
var _card_status: Label
var _charm_buttons: Array[Button] = []
var _picked_card := false
var _picked_charm := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Boss and elite rewards offer both cards and charms, so use a tighter layout to fit on screen.
	var compact: bool = params.get("cards", 0) > 0 and not params.get("charms", []).is_empty()
	var card_scale := 1.0 if compact else 1.15
	var col := UIKit.vbox(8 if compact else 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = Hud.HEIGHT
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	col.add_child(UIKit.title(params.get("title", "REWARDS"), 64 if compact else 84, UIKit.GOLD))
	col.add_child(UIKit.label(params.get("subtitle", ""), 22, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	var gold: int = params.get("gold", 0)
	if gold > 0:
		var gl := UIKit.hbox(10)
		gl.alignment = BoxContainer.ALIGNMENT_CENTER
		gl.add_child(Glyph.new("coin", UIKit.GOLD, 34))
		gl.add_child(UIKit.label("+%d gold" % gold, 28, UIKit.GOLD, true))
		col.add_child(gl)
	col.add_child(UIKit.spacer(0, 4 if compact else 14))

	var card_count: int = params.get("cards", 0)
	if card_count > 0:
		_card_status = UIKit.label("CHOOSE A CARD TO ADD TO YOUR DECK", 20, UIKit.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
		col.add_child(_card_status)
		var row := UIKit.hbox(46)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(row)
		for card in CardFactory.reward_choices(card_count, RunState.act, params.get("card_bonus", 0.0), RunState.has_charm("tricksters_pact")):
			var holder := UIKit.vbox(6 if compact else 12)
			var box := Control.new()
			box.custom_minimum_size = CardView.CARD_SIZE * card_scale + Vector2(0, 34)
			holder.add_child(box)
			var v := CardView.new(card)
			v.scale = Vector2(card_scale, card_scale)
			v.position = CardView.CARD_SIZE * (card_scale - 1.0) / 2.0 + Vector2(0, 30)
			v.interactive = true
			v.clicked.connect(_on_card_picked)
			box.add_child(v)
			_card_views.append(v)
			var name_label := UIKit.label(card.title(), 17, UIKit.TEXT_MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
			name_label.custom_minimum_size.x = CardView.CARD_SIZE.x * card_scale
			holder.add_child(name_label)
			row.add_child(holder)

	var charms: Array = params.get("charms", [])
	if not charms.is_empty():
		col.add_child(UIKit.spacer(0, 2 if compact else 6))
		col.add_child(UIKit.label("CHOOSE A CHARM", 20, UIKit.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
		var crow := UIKit.hbox(22)
		crow.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(crow)
		for id in charms:
			var b := charm_button(id)
			b.pressed.connect(_on_charm_picked.bind(id, b))
			crow.add_child(b)
			_charm_buttons.append(b)

	col.add_child(UIKit.spacer(0, 6 if compact else 18))
	var buttons := UIKit.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	if card_count > 0:
		var skip := UIKit.button("SKIP CARD", "GhostButton", Vector2(200, 0))
		skip.pressed.connect(func():
			skip.disabled = true
			_card_status.text = "Card skipped."
			_card_status.add_theme_color_override("font_color", UIKit.TEXT_MUTED)
			_lock_cards(null))
		buttons.add_child(skip)
	var cont := UIKit.button("CONTINUE", "AccentButton", Vector2(260, 60))
	cont.pressed.connect(func(): router.reward_done(params))
	buttons.add_child(cont)

# charm_button
# DESCRIPTION: A large button showing a charm's icon, name and effect. Shared with the shop.
static func charm_button(id: String) -> Button:
	var def := Charms.get_def(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 170)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var inner := UIKit.vbox(6)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 16
	inner.offset_right = -16
	inner.offset_top = 14
	inner.offset_bottom = -12
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	var icon := CharmIcon.new(id, 56)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(icon)
	inner.add_child(UIKit.label(def.name, 21, def.color.lightened(0.2), true, HORIZONTAL_ALIGNMENT_CENTER))
	var desc := UIKit.label(def.desc, 16, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 260
	inner.add_child(desc)
	# Buttons don't grow with their children, so stretch the button to fit the wrapped description.
	var fit := func():
		b.custom_minimum_size.y = maxf(170.0, inner.get_combined_minimum_size().y + 28.0)
	inner.minimum_size_changed.connect(fit)
	fit.call()
	return b

func _on_card_picked(view: CardView) -> void:
	if _picked_card:
		return
	RunState.add_card(view.data)
	Sfx.play("power")
	_lock_cards(view)
	_card_status.text = "Added %s to your deck." % view.data.title()
	_card_status.add_theme_color_override("font_color", UIKit.SUCCESS)

func _lock_cards(chosen: CardView) -> void:
	_picked_card = true
	for v in _card_views:
		v.interactive = false
		v.hovered = false
		if v == chosen:
			v.selected = true
		else:
			var tw := create_tween()
			tw.tween_property(v, "modulate:a", 0.2, 0.25)

func _on_charm_picked(id: String, button: Button) -> void:
	if _picked_charm:
		return
	_picked_charm = true
	RunState.add_charm(id)
	Sfx.play("power")
	for b in _charm_buttons:
		b.disabled = true
		if b != button:
			create_tween().tween_property(b, "modulate:a", 0.25, 0.25)
