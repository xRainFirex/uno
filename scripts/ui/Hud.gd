# ==========================================
# FILE: Hud.gd
# DESCRIPTION: Top bar shown during a run: HP, gold, act/floor, charms, deck and menu buttons.
# VERSION: v0.100
# ==========================================
class_name Hud
extends PanelContainer

signal deck_pressed
signal menu_pressed

const HEIGHT := 72.0

var _hp_bar: ProgressBar
var _hp_label: Label
var _gold_label: Label
var _floor_label: Label
var _charm_box: HBoxContainer
var _deck_button: Button
var _shown_hp := -1.0
var _shown_gold := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size.y = HEIGHT
	var sb := UIKit.stylebox(Color(0.035, 0.05, 0.07, 0.92), 0)
	sb.border_width_bottom = 2
	sb.border_color = Color(UIKit.GOLD, 0.25)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.shadow_size = 12
	sb.shadow_color = Color(0, 0, 0, 0.35)
	add_theme_stylebox_override("panel", sb)

	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(row)

	row.add_child(_centered_glyph("heart", UIKit.DANGER))
	var hp_stack := Control.new()
	hp_stack.custom_minimum_size = Vector2(220, 26)
	hp_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hp_stack)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_bar.add_theme_stylebox_override("background", UIKit.stylebox(Color(0.15, 0.05, 0.07), 8, 2, Color(0, 0, 0, 0.5)))
	_hp_bar.add_theme_stylebox_override("fill", UIKit.stylebox(UIKit.DANGER, 8))
	hp_stack.add_child(_hp_bar)
	_hp_label = UIKit.label("", 17, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hp_label.add_theme_constant_override("outline_size", 4)
	hp_stack.add_child(_hp_label)

	row.add_child(UIKit.spacer(18))
	row.add_child(_centered_glyph("coin", UIKit.GOLD))
	_gold_label = UIKit.label("0", 24, UIKit.GOLD, true)
	_gold_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gold_label.custom_minimum_size.x = 60
	row.add_child(_gold_label)

	row.add_child(UIKit.spacer(18))
	row.add_child(_centered_glyph("map", UIKit.TEXT_MUTED))
	_floor_label = UIKit.label("", 20, UIKit.TEXT, true)
	_floor_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_floor_label)

	row.add_child(UIKit.expand_spacer())
	_charm_box = UIKit.hbox(6)
	_charm_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_charm_box)
	row.add_child(UIKit.spacer(18))

	_deck_button = UIKit.button("DECK", "GhostButton")
	_deck_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_deck_button.tooltip_text = "View your deck"
	_deck_button.pressed.connect(func(): deck_pressed.emit())
	row.add_child(_deck_button)
	var menu := UIKit.button("MENU", "GhostButton")
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.tooltip_text = "Pause (Esc)"
	menu.pressed.connect(func(): menu_pressed.emit())
	row.add_child(menu)

	RunState.changed.connect(refresh)
	refresh()

func _centered_glyph(icon: String, col: Color) -> Glyph:
	var g := Glyph.new(icon, col, 30)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return g

# refresh
# DESCRIPTION: Pulls current values from RunState and animates HP/gold changes.
func refresh() -> void:
	_hp_bar.max_value = RunState.max_hp
	if _shown_hp < 0.0:
		_shown_hp = RunState.hp
		_hp_bar.value = RunState.hp
	else:
		if RunState.hp < _shown_hp:
			_pulse(_hp_bar.get_parent(), UIKit.DANGER)
		create_tween().tween_property(_hp_bar, "value", float(RunState.hp), 0.35).set_trans(Tween.TRANS_CUBIC)
		_shown_hp = RunState.hp
	_hp_label.text = "%d / %d" % [maxi(RunState.hp, 0), RunState.max_hp]
	if _shown_gold >= 0 and RunState.gold != _shown_gold:
		_pulse(_gold_label, UIKit.GOLD)
	_shown_gold = RunState.gold
	_gold_label.text = str(RunState.gold)
	var row := 0 if RunState.current_node < 0 else int(RunState.map_nodes[RunState.current_node].row) + 1
	_floor_label.text = "ACT %s  ·  FLOOR %d" % [["I", "II", "III"][clampi(RunState.act - 1, 0, 2)], row]
	_deck_button.text = "DECK  %d" % RunState.deck.size()
	for c in _charm_box.get_children():
		c.queue_free()
	for id in RunState.charms:
		_charm_box.add_child(CharmIcon.new(id, 44))

func _pulse(node: Control, _col: Color) -> void:
	node.pivot_offset = node.size / 2.0
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.18, 1.18), 0.08)
	tw.tween_property(node, "scale", Vector2.ONE, 0.18)
