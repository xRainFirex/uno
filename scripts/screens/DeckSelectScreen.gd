# ==========================================
# FILE: DeckSelectScreen.gd
# DESCRIPTION: Pick a starting deck before a run. Shows one deck at a time (arrows / arrow keys to browse)
#              with every card in it, its perk, and your lifetime record with that deck.
# VERSION: v0.100
# ==========================================
class_name DeckSelectScreen
extends Control

const PREVIEW_SIZE := Vector2(820, 560)

var router: Node
var _index := 0
var _panel_slot: CenterContainer
var _dots: HBoxContainer
var _start: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_index = maxi(0, StarterDecks.ORDER.find(RunState.deck_id))

	var col := UIKit.vbox(14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	col.add_child(UIKit.title("CHOOSE YOUR DECK", 56, UIKit.GOLD))
	col.add_child(UIKit.label("Win a run with a deck to unlock the next one.", 19, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))

	var row := UIKit.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var prev := _arrow_button("<", -1)
	row.add_child(prev)
	_panel_slot = CenterContainer.new()
	_panel_slot.custom_minimum_size = Vector2(1500, 640)
	row.add_child(_panel_slot)
	var next := _arrow_button(">", 1)
	row.add_child(next)

	_dots = UIKit.hbox(10)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_dots)

	var buttons := UIKit.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	var back := UIKit.button("BACK", "GhostButton", Vector2(200, 60))
	back.pressed.connect(func(): router.show_title())
	buttons.add_child(back)
	_start = UIKit.button("START RUN", "AccentButton", Vector2(280, 60))
	_start.pressed.connect(func():
		var id: String = StarterDecks.ORDER[_index]
		if RunState.is_deck_unlocked(id):
			router.start_run(id))
	buttons.add_child(_start)
	_show()

func _arrow_button(text: String, step: int) -> Button:
	var b := UIKit.button(text, "", Vector2(76, 120))
	b.add_theme_font_size_override("font_size", 44)
	b.tooltip_text = "Previous deck" if step < 0 else "Next deck"
	b.pressed.connect(func(): _step(step))
	return b

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_step(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_step(1)
		get_viewport().set_input_as_handled()

func _step(step: int) -> void:
	_index = posmod(_index + step, StarterDecks.ORDER.size())
	Sfx.play("card")
	_show()

# _show
# DESCRIPTION: Rebuilds the panel for the current deck.
func _show() -> void:
	for c in _panel_slot.get_children():
		c.queue_free()
	var id: String = StarterDecks.ORDER[_index]
	var def := StarterDecks.get_def(id)
	var unlocked := RunState.is_deck_unlocked(id)
	var accent: Color = def.color if unlocked else Color(0.45, 0.47, 0.52)

	var panel := UIKit.panel(22)
	panel.custom_minimum_size = Vector2(1460, 600)
	_panel_slot.add_child(panel)
	var body := UIKit.hbox(34)
	panel.add_child(body)

	# Left: name, description, perk, starting stats and lifetime record.
	var info := UIKit.vbox(10)
	info.custom_minimum_size.x = 520
	body.add_child(info)
	var head := UIKit.hbox(16)
	head.add_child(Glyph.new(def.icon if unlocked else "text:?", accent, 64))
	var names := UIKit.vbox(0)
	names.add_child(UIKit.label("DECK %d OF %d" % [_index + 1, StarterDecks.ORDER.size()], 15, UIKit.TEXT_MUTED, true))
	names.add_child(UIKit.title(def.name.to_upper(), 46, accent.lightened(0.15)))
	names.get_child(1).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(names)
	info.add_child(head)

	if unlocked:
		info.add_child(_wrapped(def.desc, 19, UIKit.TEXT))
		info.add_child(_wrapped(def.perk, 19, UIKit.GOLD))
		var cards := StarterDecks.build(id)
		info.add_child(UIKit.label("%d cards   ·   %d HP   ·   %d gold" % [cards.size(), RunState.START_HP + int(def.hp), RunState.START_GOLD + int(def.gold)], 18, UIKit.TEXT_MUTED, true))
	else:
		var prev_name: String = StarterDecks.get_def(StarterDecks.ORDER[_index - 1]).name
		info.add_child(_wrapped("Locked. Win a run with the %s deck to unlock it." % prev_name, 20, UIKit.TEXT_MUTED))
	info.add_child(UIKit.spacer(0, 6))
	info.add_child(UIKit.label("YOUR RECORD", 16, UIKit.TEXT_MUTED, true))
	info.add_child(_stats_grid(id))

	# Right: every card in the deck, laid out in a grid.
	var preview := Control.new()
	preview.custom_minimum_size = PREVIEW_SIZE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(preview)
	_fill_preview(preview, StarterDecks.build(id), unlocked)

	# Dots
	for c in _dots.get_children():
		c.queue_free()
	for i in StarterDecks.ORDER.size():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(14, 14)
		var on := i == _index
		var col := UIKit.GOLD if on else (Color(1, 1, 1, 0.35) if RunState.is_deck_unlocked(StarterDecks.ORDER[i]) else Color(1, 1, 1, 0.12))
		dot.add_theme_stylebox_override("panel", UIKit.stylebox(col, 7))
		_dots.add_child(dot)

	_start.disabled = not unlocked
	_start.text = "START RUN" if unlocked else "LOCKED"

func _wrapped(text: String, size: int, col: Color) -> Label:
	var l := UIKit.label(text, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 500
	return l

func _stats_grid(id: String) -> GridContainer:
	var st: Dictionary = RunState.meta.deck_stats.get(id, {})
	var runs := int(st.get("runs", 0))
	var wins := int(st.get("wins", 0))
	var losses := int(st.get("losses", 0))
	var rate := "-" if wins + losses == 0 else "%d%%" % int(round(100.0 * wins / (wins + losses)))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	var rows := [
		["Runs", str(runs)], ["Win rate", rate],
		["Wins", str(wins)], ["Best floor", str(int(st.get("best_floor", 0)))],
		["Losses", str(losses)], ["Battles won", str(int(st.get("battles_won", 0)))],
	]
	for r in rows:
		grid.add_child(UIKit.label(r[0], 18, UIKit.TEXT_MUTED))
		grid.add_child(UIKit.label(r[1], 18, UIKit.TEXT, true))
	return grid

# _fill_preview
# DESCRIPTION: Lays every card out in rows, shrinking them so the whole deck fits the preview area.
func _fill_preview(area: Control, cards: Array, face_up: bool) -> void:
	cards.sort_custom(func(a, b): return a.sort_key() < b.sort_key())
	var n := cards.size()
	var gap := 8.0
	var best_scale := 0.0
	var best_cols := 1
	for cols in range(1, n + 1):
		var rows := ceili(float(n) / cols)
		var sx := (PREVIEW_SIZE.x - gap * (cols - 1)) / (cols * CardView.CARD_SIZE.x)
		var sy := (PREVIEW_SIZE.y - gap * (rows - 1)) / (rows * CardView.CARD_SIZE.y)
		var s := minf(minf(sx, sy), 0.9)
		if s > best_scale:
			best_scale = s
			best_cols = cols
	var cell := CardView.CARD_SIZE * best_scale
	var rows_used := ceili(float(n) / best_cols)
	var total := Vector2(best_cols * cell.x + (best_cols - 1) * gap, rows_used * cell.y + (rows_used - 1) * gap)
	var origin := (PREVIEW_SIZE - total) / 2.0
	for i in n:
		var v := CardView.new(cards[i], face_up)
		v.scale = Vector2(best_scale, best_scale)
		var cell_pos := origin + Vector2((i % best_cols) * (cell.x + gap), (i / best_cols) * (cell.y + gap))
		# CardView scales around its centre, so offset by the shrinkage.
		v.position = cell_pos - CardView.CARD_SIZE * (1.0 - best_scale) / 2.0
		v.interactive = face_up
		v.hover_lift = 0.0
		v.hover_grow = 0.04 / best_scale
		area.add_child(v)
