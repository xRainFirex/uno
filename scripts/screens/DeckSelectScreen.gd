# ==========================================
# FILE: DeckSelectScreen.gd
# DESCRIPTION: Pick a starting deck before a run. Locked decks show what unlocks them.
# VERSION: v0.100
# ==========================================
class_name DeckSelectScreen
extends Control

var router: Node
var _selected := ""
var _buttons := {}
var _start: Button
var _info: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selected = RunState.deck_id if RunState.is_deck_unlocked(RunState.deck_id) else "classic"

	var col := UIKit.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	col.add_child(UIKit.title("CHOOSE YOUR DECK", 60, UIKit.GOLD))
	col.add_child(UIKit.label("Win a run with a deck to unlock the next one.", 20, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.spacer(0, 8))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	for id in StarterDecks.ORDER:
		var b := _deck_button(id)
		grid.add_child(b)
		_buttons[id] = b

	_info = UIKit.label("", 19, UIKit.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_info)

	var row := UIKit.hbox(16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var back := UIKit.button("BACK", "GhostButton", Vector2(180, 60))
	back.pressed.connect(func(): router.show_title())
	row.add_child(back)
	var view := UIKit.button("VIEW CARDS", "", Vector2(200, 60))
	view.pressed.connect(func():
		var cards := StarterDecks.build(_selected)
		router.open_deck(StarterDecks.get_def(_selected).name.to_upper() + " DECK", cards))
	row.add_child(view)
	_start = UIKit.button("START RUN", "AccentButton", Vector2(260, 60))
	_start.pressed.connect(func(): router.start_run(_selected))
	row.add_child(_start)
	_select(_selected)

# _deck_button
# DESCRIPTION: A card-like tile showing the deck's icon, description, perk and win count (or how to unlock it).
func _deck_button(id: String) -> Button:
	var def := StarterDecks.get_def(id)
	var unlocked := RunState.is_deck_unlocked(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(400, 250)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if unlocked else Control.CURSOR_FORBIDDEN
	b.toggle_mode = true
	var col: Color = def.color if unlocked else Color(0.4, 0.42, 0.46)
	b.add_theme_stylebox_override("pressed", UIKit.stylebox(UIKit.PANEL_LIGHT.lightened(0.05), 14, 4, UIKit.GOLD, 12))
	var inner := UIKit.vbox(6)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 18
	inner.offset_right = -18
	inner.offset_top = 14
	inner.offset_bottom = -12
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	var head := UIKit.hbox(12)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(Glyph.new(def.icon if unlocked else "text:?", col, 44))
	var name_col := UIKit.vbox(0)
	name_col.add_child(UIKit.label(def.name.to_upper(), 26, col.lightened(0.2), true))
	var count := StarterDecks.build(id).size()
	var wins := int(RunState.meta.deck_wins.get(id, 0))
	var sub := "%d cards" % count + ("   ·   won %d×" % wins if wins > 0 else "")
	name_col.add_child(UIKit.label(sub, 15, UIKit.TEXT_MUTED, true))
	head.add_child(name_col)
	inner.add_child(head)
	var desc_text: String = def.desc if unlocked else "Locked. Win a run with the %s deck to unlock." % StarterDecks.get_def(StarterDecks.ORDER[StarterDecks.ORDER.find(id) - 1]).name
	var desc := UIKit.label(desc_text, 16, UIKit.TEXT if unlocked else UIKit.TEXT_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = 360
	inner.add_child(desc)
	if unlocked:
		var perk := UIKit.label(def.perk, 16, UIKit.GOLD)
		perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		perk.custom_minimum_size.x = 360
		inner.add_child(perk)
	for c in inner.find_children("*", "Control", true, false):
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.disabled = not unlocked
	b.pressed.connect(func(): _select(id))
	return b

func _select(id: String) -> void:
	if not RunState.is_deck_unlocked(id):
		return
	_selected = id
	for k in _buttons:
		(_buttons[k] as Button).set_pressed_no_signal(k == id)
	var def := StarterDecks.get_def(id)
	var hp := RunState.START_HP + int(def.hp)
	_info.text = "%s  ·  %d HP  ·  %d gold" % [def.name, hp, RunState.START_GOLD + int(def.gold)]
