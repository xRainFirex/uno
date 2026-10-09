# ==========================================
# FILE: BattleScreen.gd
# DESCRIPTION: The card table. Drives the turn loop over BattleState, animates every card movement,
#              and handles DOS! calls, catching, colour picking and the end-of-battle result.
# VERSION: v0.100
# ==========================================
class_name BattleScreen
extends Control

signal _player_done
signal _color_chosen(color: int)
signal _catch_resolved(caught: bool)

const P := BattleState.PLAYER
const E := BattleState.ENEMY
const MAX_PILE_VIEWS := 10

var router: Node
var enemy: Dictionary = {}

var state: BattleState
var _layer: Control
var _views := {}                 # CardData -> CardView for cards in hands
var _hand_views: Array = [[], []]
var _pile_views: Array[CardView] = []
var _deck_views: Array[CardView] = [null, null]
var _deck_labels: Array[Label] = [null, null]
var _seer_view: CardView
var _ring: ActiveColorRing
var _status_label: Label
var _status_dot: Panel
var _log: RichTextLabel
var _avatar: Avatar
var _enemy_count_label: Label
var _hand_count_label: Label
var _dos_button: Button
var _pass_button: Button
var _catch_button: Button
var _color_modal: Control

var _awaiting := false
var _busy := false
var _drawn_card: CardData = null
var _dos_called := false
var _modal := false
var _finished := false
var _catch_open := false
var _hovered: CardView
var _bonus_turn := false
var _time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	state = BattleState.new()
	var player_hand := 7 - (1 if RunState.has_charm("light_pack") else 0)
	var enemy_hand: int = enemy.hand + (1 if RunState.has_charm("heavy_burden") else 0)
	state.setup(RunState.deck, CardFactory.enemy_deck(enemy.deck, RunState.act, enemy.kind), RunState.charms, enemy.abilities, player_hand, enemy_hand)
	_build_ui()
	resized.connect(_layout_all)
	_intro.call_deferred()

# ---------- Layout helpers ----------

func _center() -> Vector2:
	return Vector2(size.x / 2.0, size.y * 0.5 - 6.0)

func _deck_pos(side: int) -> Vector2:
	return _center() + Vector2(-290.0 if side == P else 290.0, 0)

func _hand_y(side: int) -> float:
	return size.y - 128.0 if side == P else Hud.HEIGHT + 118.0

# ---------- UI construction ----------

func _build_ui() -> void:
	_ring = ActiveColorRing.new()
	add_child(_ring)

	# Draw piles
	for side in 2:
		var deck := CardView.new(null, false)
		deck.animate_motion = true
		deck.hover_lift = 10.0 if side == P else 0.0
		if side == P:
			deck.interactive = true
			deck.show_tooltip = false
			deck.tooltip_text = "Draw a card (Space)"
			deck.clicked.connect(func(_v): _on_deck_clicked())
		else:
			deck.target_scale = Vector2(0.8, 0.8)
			deck.scale = deck.target_scale
		add_child(deck)
		_deck_views[side] = deck
		var lbl := UIKit.label("", 17, UIKit.TEXT_MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
		lbl.custom_minimum_size = Vector2(240, 0)
		add_child(lbl)
		_deck_labels[side] = lbl

	_hand_count_label = UIKit.label("", 20, UIKit.TEXT_MUTED, true)
	add_child(_hand_count_label)

	_layer = Control.new()
	_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layer)

	# Opponent panel
	var enemy_panel := UIKit.panel(18)
	enemy_panel.position = Vector2(36, Hud.HEIGHT + 24)
	enemy_panel.custom_minimum_size = Vector2(430, 0)
	add_child(enemy_panel)
	var erow := UIKit.hbox(18)
	enemy_panel.add_child(erow)
	_avatar = Avatar.new(enemy, 104)
	_avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	erow.add_child(_avatar)
	var einfo := UIKit.vbox(4)
	einfo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erow.add_child(einfo)
	var kind_tag: String = {"battle": "", "elite": "ELITE  ·  ", "boss": "BOSS  ·  "}[enemy.kind]
	if int(enemy.get("attempt", 1)) > 1:
		kind_tag = "REMATCH #%d  ·  " % int(enemy.attempt) + kind_tag
	einfo.add_child(UIKit.label(kind_tag + enemy.title.to_upper(), 15, UIKit.DANGER if enemy.kind != "battle" else UIKit.TEXT_MUTED, true))
	einfo.add_child(UIKit.label(enemy.name, 30, UIKit.TEXT, true))
	var hits := UIKit.label("Hits for %d per card left in your hand" % enemy.attack, 16, UIKit.TEXT_MUTED)
	einfo.add_child(hits)
	for line in Enemies.ability_lines(enemy):
		var al := UIKit.label(line, 16, UIKit.GOLD)
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		al.custom_minimum_size.x = 280
		einfo.add_child(al)
	# Count the trick cards actually in their deck (themed archetypes plus the act/elite/boss extras).
	var tricks := 0
	for c in state.draw_piles[E] + state.hands[E]:
		if c.is_dual() or c.type >= CardData.Type.DOUBLE_DOWN or c.type == CardData.Type.WILD_SWAP:
			tricks += 1
	if tricks > 0:
		einfo.add_child(UIKit.label("Deck holds %d trick card%s" % [tricks, "" if tricks == 1 else "s"], 16, Color(0.75, 0.6, 1.0), true))
	_enemy_count_label = UIKit.label("", 18, UIKit.TEXT, true)
	einfo.add_child(_enemy_count_label)

	# Status pill
	var pill := PanelContainer.new()
	var pill_sb := UIKit.stylebox(Color(0.02, 0.03, 0.05, 0.75), 30, 2, Color(1, 1, 1, 0.08))
	pill_sb.content_margin_left = 26
	pill_sb.content_margin_right = 30
	pill_sb.content_margin_top = 10
	pill_sb.content_margin_bottom = 10
	pill.add_theme_stylebox_override("panel", pill_sb)
	pill.name = "StatusPill"
	add_child(pill)
	var prow := UIKit.hbox(12)
	pill.add_child(prow)
	_status_dot = Panel.new()
	_status_dot.custom_minimum_size = Vector2(14, 14)
	_status_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_status_dot.add_theme_stylebox_override("panel", UIKit.stylebox(UIKit.SUCCESS, 7))
	prow.add_child(_status_dot)
	_status_label = UIKit.label("", 22, UIKit.TEXT, true)
	prow.add_child(_status_label)

	# Battle log
	var log_panel := UIKit.panel(16)
	log_panel.name = "LogPanel"
	log_panel.custom_minimum_size = Vector2(360, 250)
	add_child(log_panel)
	var lcol := UIKit.vbox(6)
	log_panel.add_child(lcol)
	lcol.add_child(UIKit.label("BATTLE LOG", 15, UIKit.TEXT_MUTED, true))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", UIKit.fs(16))
	_log.add_theme_font_size_override("bold_font_size", UIKit.fs(16))
	lcol.add_child(_log)

	# Action buttons
	_dos_button = Button.new()
	_dos_button.text = "DOS!"
	_dos_button.focus_mode = Control.FOCUS_NONE
	_dos_button.custom_minimum_size = Vector2(150, 150)
	_dos_button.pivot_offset = Vector2(75, 75)
	_dos_button.tooltip_text = "Call DOS! before playing your second-to-last card (D)"
	_dos_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var col := UIKit.DANGER
		if st == "hover":
			col = col.lightened(0.12)
		elif st == "pressed":
			col = col.darkened(0.2)
		elif st == "disabled":
			col = Color(0.25, 0.12, 0.13)
		var sb := UIKit.stylebox(col, 0, 6, UIKit.GOLD if st != "disabled" else Color(0.35, 0.3, 0.2), 12 if st != "disabled" else 0)
		_dos_button.add_theme_stylebox_override(st, sb)
	_dos_button.add_theme_font_override("font", UIKit.font_display())
	_dos_button.add_theme_font_size_override("font_size", 40)
	_dos_button.add_theme_color_override("font_color", UIKit.GOLD)
	_dos_button.add_theme_color_override("font_hover_color", Color(1, 0.9, 0.5))
	_dos_button.add_theme_color_override("font_disabled_color", Color(0.5, 0.4, 0.3))
	_dos_button.add_theme_color_override("font_outline_color", Color(0.2, 0.02, 0.03))
	_dos_button.add_theme_constant_override("outline_size", 10)
	_dos_button.pressed.connect(_on_dos_pressed)
	add_child(_dos_button)

	_pass_button = UIKit.button("PASS", "", Vector2(150, 0))
	_pass_button.tooltip_text = "Keep the drawn card and end your turn (Enter)"
	_pass_button.pressed.connect(_on_pass_pressed)
	add_child(_pass_button)

	_catch_button = UIKit.button("CATCH!  +2", "DangerButton", Vector2(220, 64))
	_catch_button.add_theme_font_size_override("font_size", UIKit.fs(28))
	_catch_button.visible = false
	_catch_button.pressed.connect(func():
		if _catch_open:
			_catch_open = false
			_catch_button.visible = false
			_catch_resolved.emit(true))
	add_child(_catch_button)

	if RunState.has_charm("seer"):
		_seer_view = CardView.new(null, true)
		_seer_view.scale = Vector2(0.55, 0.55)
		_seer_view.modulate = Color(1, 1, 1, 0.92)
		_seer_view.tooltip_text = "Seer's Eye: the next card you will draw"
		add_child(_seer_view)
		var seer_label := UIKit.label("NEXT", 14, UIKit.TEXT_MUTED, true, HORIZONTAL_ALIGNMENT_CENTER)
		seer_label.name = "SeerLabel"
		add_child(seer_label)

	_build_color_modal()
	_layout_all()
	_refresh_info()

func _build_color_modal() -> void:
	_color_modal = Control.new()
	_color_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_color_modal.visible = false
	_color_modal.z_index = 500
	_color_modal.add_child(UIKit.dimmer(0.55))
	var panel := UIKit.panel(24)
	_color_modal.add_child(UIKit.centered(panel))
	var col := UIKit.vbox(18)
	panel.add_child(col)
	col.add_child(UIKit.title("CHOOSE A COLOUR", 40, UIKit.TEXT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	col.add_child(grid)
	for i in 4:
		var b := Button.new()
		b.name = "Color%d" % i
		b.custom_minimum_size = Vector2(210, 130)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var base := UIKit.card_color(i)
		b.add_theme_stylebox_override("normal", UIKit.stylebox(base, 18, 4, base.lightened(0.3), 8))
		b.add_theme_stylebox_override("hover", UIKit.stylebox(base.lightened(0.15), 18, 6, Color.WHITE, 14))
		b.add_theme_stylebox_override("pressed", UIKit.stylebox(base.darkened(0.15), 18, 4, Color.WHITE))
		b.add_theme_font_override("font", UIKit.font_display())
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
		b.add_theme_constant_override("outline_size", 8)
		b.pressed.connect(func():
			Sfx.play("click")
			_color_chosen.emit(i))
		grid.add_child(b)
	add_child(_color_modal)

func _layout_all() -> void:
	if _layer == null:
		return
	var c := _center()
	_ring.position = c - _ring.size / 2.0
	for side in 2:
		_deck_views[side].target_center = _deck_pos(side)
		if _deck_views[side].position == Vector2.ZERO:
			_deck_views[side].place_at(_deck_pos(side))
		_deck_labels[side].position = _deck_pos(side) + Vector2(-120, 112 if side == P else 92)
	if _seer_view:
		_seer_view.position = _deck_pos(P) + Vector2(-150, -60) - _seer_view.size / 2.0
		var seer_label := get_node("SeerLabel") as Label
		seer_label.position = _deck_pos(P) + Vector2(-150 - 30, -60 + 56)
		seer_label.custom_minimum_size.x = 60
	var pill := get_node("StatusPill") as Control
	pill.reset_size()
	pill.position = Vector2(c.x - pill.size.x / 2.0, c.y - 200.0)
	var log_panel := get_node("LogPanel") as Control
	log_panel.position = Vector2(size.x - 396, Hud.HEIGHT + 24)
	_dos_button.position = Vector2(size.x - 250, size.y - 390)
	_pass_button.position = Vector2(size.x - 250, size.y - 210)
	_catch_button.position = Vector2(c.x + 260, _hand_y(E) + 30)
	_hand_count_label.position = Vector2(40, size.y - 64)
	for i in _pile_views.size():
		var v := _pile_views[i]
		v.target_center = c + v.get_meta("offset", Vector2.ZERO)
	_layout_hands()

# _layout_hands
# DESCRIPTION: Fans both hands in an arc. Player cards face up at the bottom, opponent cards upside down at the top.
func _layout_hands() -> void:
	for side in 2:
		var list: Array = _hand_views[side]
		var n := list.size()
		if n == 0:
			continue
		var max_width := minf(size.x - 900.0, 1040.0) if side == P else 640.0
		var spacing := minf(108.0 if side == P else 62.0, max_width / maxf(1.0, n - 1))
		var deg := clampf(26.0 / n, 1.2, 4.5)
		for i in n:
			var v: CardView = list[i]
			var off := i - (n - 1) / 2.0
			var x := size.x / 2.0 + off * spacing
			if side == P:
				v.target_center = Vector2(x, _hand_y(P) + off * off * 1.6)
				v.target_rotation = deg_to_rad(off * deg)
				v.target_scale = Vector2.ONE
				v.z_index = 60 if v == _hovered else 10 + i
			else:
				v.target_center = Vector2(x, _hand_y(E) - off * off * 1.0)
				# Cards revealed by the Spyglass are shown upright so they're readable.
				v.target_rotation = (0.0 if v.face_up else PI) - deg_to_rad(off * deg * 0.8)
				v.target_scale = Vector2(0.78, 0.78)
				v.z_index = 10 + i

# ---------- Card view syncing ----------

func _spawn(card: CardData, at: Vector2, face_up: bool) -> CardView:
	var v := CardView.new(card, face_up)
	v.animate_motion = true
	v.place_at(at, 0.0)
	if at == _deck_pos(E):
		v.scale = Vector2(0.8, 0.8)
	_layer.add_child(v)
	return v

# _sync_hands
# DESCRIPTION: Reconciles card views with the rules state. New cards fly in from their owner's deck,
#              cards that left a hand (Discard All) fly to the pile, swapped hands fly across the table.
func _sync_hands() -> void:
	var keep := {}
	for side in 2:
		var list: Array = []
		var reveal_index := 0 if (side == E and RunState.has_charm("spyglass")) else -1
		for i in state.hands[side].size():
			var card: CardData = state.hands[side][i]
			var v: CardView = _views.get(card)
			var want_face: bool = side == P or i == reveal_index
			if v == null:
				v = _spawn(card, _deck_pos(side), false)
				_views[card] = v
				if want_face:
					_flip_later(v, true, 0.18)
			elif v.face_up != want_face:
				v.flip_to(want_face)
			list.append(v)
			keep[card] = true
		_hand_views[side] = list
	for card in _views.keys():
		if not keep.has(card):
			var v: CardView = _views[card]
			_views.erase(card)
			_send_to_pile(v, false)
	if _hovered != null and not _hand_views[P].has(_hovered):
		_hovered = null
	_layout_hands()
	_refresh_info()

func _flip_later(v: CardView, up: bool, delay: float) -> void:
	var t := get_tree().create_timer(delay)
	t.timeout.connect(func():
		if is_instance_valid(v):
			v.flip_to(up))

# _send_to_pile
# DESCRIPTION: Moves a card view onto the discard pile with a slightly random resting angle.
func _send_to_pile(v: CardView, on_top: bool) -> void:
	v.hovered = false
	v.playable = false
	v.dimmed = false
	if not v.face_up:
		v.flip_to(true, 0.2)
	var offset := Vector2(randf_range(-12, 12), randf_range(-10, 10))
	v.set_meta("offset", offset)
	v.target_center = _center() + offset
	v.target_rotation = randf_range(-0.3, 0.3)
	v.target_scale = Vector2.ONE
	v.motion_speed = 9.0
	if on_top:
		_pile_views.append(v)
		v.z_index = 200
	else:
		_pile_views.insert(maxi(0, _pile_views.size() - 1), v)
		v.z_index = 150
	_layer.move_child(v, -1)
	while _pile_views.size() > MAX_PILE_VIEWS:
		var old: CardView = _pile_views.pop_front()
		old.queue_free()
	_reset_pile_z.call_deferred()

func _reset_pile_z() -> void:
	await _wait(0.6)
	for i in _pile_views.size():
		_pile_views[i].z_index = i

# ---------- Info / controls ----------

func _refresh_info() -> void:
	for side in 2:
		var d := state.deck_count(side)
		var dis := state.discard_count(side)
		var owner_name: String = "YOUR DECK" if side == P else "%s'S DECK" % enemy.name.to_upper()
		_deck_labels[side].text = "%s  %d" % [owner_name, d] + ("   ·   DISCARD %d" % dis if dis > 0 else "")
		_deck_views[side].visible = d > 0 or dis > 0
	_enemy_count_label.text = _count_text(state.hands[E].size(), "cards in hand")
	_enemy_count_label.add_theme_color_override("font_color", _count_color(state.hands[E].size(), UIKit.TEXT))
	_hand_count_label.text = _count_text(state.hands[P].size(), "CARDS IN HAND")
	_hand_count_label.add_theme_color_override("font_color", _count_color(state.hands[P].size(), UIKit.TEXT_MUTED))
	_ring.target_color = UIKit.card_color(state.active_color)
	if _seer_view:
		var top := state.peek_top_of_deck(P)
		_seer_view.visible = top != null
		_seer_view.data = top
	_refresh_controls()

func _refresh_controls() -> void:
	var my_turn := _awaiting and not _busy and not _modal
	var any_playable := false
	for v in _hand_views[P]:
		var card: CardData = v.data
		var ok := my_turn and state.can_play(card, P) and (_drawn_card == null or card == _drawn_card)
		v.playable = ok
		v.dimmed = my_turn and not ok
		any_playable = any_playable or ok
	_deck_views[P].playable = my_turn and _drawn_card == null and not any_playable and state.can_draw(P)
	var dos_ready: bool = my_turn and state.hands[P].size() == 2 and any_playable and not _dos_called
	_dos_button.disabled = not dos_ready
	_pass_button.visible = my_turn and _drawn_card != null

# _count_text / _count_color
# DESCRIPTION: Hand-size readouts that warn as a hand nears the Bust limit.
func _count_text(n: int, suffix: String) -> String:
	if n >= BattleState.BUST_LIMIT - 7:
		return "%d %s  ·  BUST AT %d!" % [n, suffix, BattleState.BUST_LIMIT]
	return "%d %s" % [n, suffix]

func _count_color(n: int, normal: Color) -> Color:
	return UIKit.DANGER if n >= BattleState.BUST_LIMIT - 7 else normal

func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	(_status_dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = color
	var pill := get_node("StatusPill") as Control
	pill.reset_size()
	pill.position.x = size.x / 2.0 - pill.size.x / 2.0

func _log_line(text: String) -> void:
	_log.append_text(text + "\n")

func _card_bb(card: CardData) -> String:
	var col := UIKit.card_color(card.effective_color() if (card.is_wild() or card.is_dual()) and card.chosen_color >= 0 else card.card_color)
	if card.is_wild() and card.chosen_color < 0:
		col = Color(0.85, 0.85, 0.95)
	return "[color=#%s][b]%s[/b][/color]" % [col.lightened(0.15).to_html(false), card.title()]

func _wait(seconds: float) -> void:
	var t := Timer.new()
	t.one_shot = true
	add_child(t)
	t.start(seconds * (0.5 if RunState.fast_mode else 1.0))
	await t.timeout
	t.queue_free()

# ---------- Floating feedback ----------

func _float_text(text: String, at: Vector2, color: Color = Color.WHITE, font_size: int = 64) -> void:
	var l := UIKit.title(text, font_size, color)
	l.z_index = 300
	add_child(l)
	l.reset_size()
	l.pivot_offset = l.size / 2.0
	l.position = at - l.size / 2.0
	l.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(0.45)
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 50.0, 0.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(l.queue_free)

func _shake(strength: float = 12.0) -> void:
	var tw := create_tween()
	for i in 6:
		tw.tween_property(_layer, "position", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * (1.0 - i / 6.0), 0.035)
	tw.tween_property(_layer, "position", Vector2.ZERO, 0.04)

func _process(delta: float) -> void:
	_time += delta
	if not _dos_button.disabled:
		var s := 1.0 + 0.06 * sin(_time * 7.0)
		_dos_button.scale = Vector2(s, s)
	else:
		_dos_button.scale = Vector2.ONE
	if _catch_open:
		var s2 := 1.0 + 0.08 * sin(_time * 12.0)
		_catch_button.pivot_offset = _catch_button.size / 2.0
		_catch_button.scale = Vector2(s2, s2)
	_update_hover()

# ---------- Input ----------

func _card_under_mouse() -> CardView:
	var m := get_local_mouse_position()
	var list: Array = _hand_views[P]
	for i in range(list.size() - 1, -1, -1):
		var v: CardView = list[i]
		var r := Rect2(v.target_center - CardView.CARD_SIZE / 2.0, CardView.CARD_SIZE)
		if v == _hovered:
			r = r.grow_individual(0, 34, 0, 0)
		if r.has_point(m):
			return v
	return null

func _update_hover() -> void:
	var v: CardView = null
	if not _blocked():
		v = _card_under_mouse()
	if v == _hovered:
		return
	if _hovered != null and is_instance_valid(_hovered):
		_hovered.hovered = false
	_hovered = v
	if v != null:
		v.hovered = true
		if v.playable:
			Sfx.play("hover", 1.0, -10.0)
	_layout_hands()

func _blocked() -> bool:
	return _modal or _finished or get_tree().paused or (router != null and router.has_overlay())

func _unhandled_input(event: InputEvent) -> void:
	if _blocked():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var v := _card_under_mouse()
		if v != null:
			get_viewport().set_input_as_handled()
			_try_play(v)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_on_deck_clicked()
			KEY_D:
				if not _dos_button.disabled:
					_on_dos_pressed()
			KEY_ENTER, KEY_KP_ENTER:
				if _pass_button.visible:
					_on_pass_pressed()
			KEY_C:
				if _catch_open:
					_catch_button.pressed.emit()

func _try_play(v: CardView) -> void:
	if not _awaiting or _busy:
		return
	var card: CardData = v.data
	if (_drawn_card != null and card != _drawn_card) or not state.can_play(card, P):
		v.shake()
		Sfx.play("error", 1.0, -4.0)
		return
	_busy = true
	_refresh_controls()
	var color := -1
	if card.is_wild():
		color = await _pick_color()
	elif card.is_dual():
		color = await _pick_color(card.colors())
	await _resolve_play(P, card, color)
	_busy = false
	_player_done.emit()

func _on_deck_clicked() -> void:
	if not _awaiting or _busy or _modal or _drawn_card != null:
		return
	if not state.can_draw(P):
		_float_text("NO CARDS LEFT", _deck_pos(P), UIKit.TEXT_MUTED, 34)
		return
	_busy = true
	var card := state.draw_one(P)
	Sfx.play("card")
	_sync_hands()
	_log_line("You drew a card.")
	await _wait(0.45)
	_busy = false
	if state.can_play(card, P):
		_drawn_card = card
		_set_status("Play the drawn card, or pass", UIKit.GOLD)
		_refresh_controls()
	else:
		_refresh_controls()
		await _wait(0.25)
		_player_done.emit()

func _on_pass_pressed() -> void:
	if not _awaiting or _busy or _drawn_card == null:
		return
	_drawn_card = null
	_log_line("You passed.")
	_player_done.emit()

func _on_dos_pressed() -> void:
	if _dos_button.disabled:
		return
	_dos_called = true
	Sfx.play("call")
	_float_text("DOS!", Vector2(size.x - 175, size.y - 430), UIKit.GOLD, 56)
	_log_line("[color=#f5c542][b]You called DOS![/b][/color]")
	_refresh_controls()

# _pick_color
# DESCRIPTION: Shows the colour picker. Dual-colour cards only offer their own two colours.
func _pick_color(allowed: Array = [0, 1, 2, 3]) -> int:
	_modal = true
	_update_hover()
	_refresh_controls()
	var counts := [0, 0, 0, 0]
	for c in state.hands[P]:
		if not c.is_wild():
			for col in c.colors():
				counts[col] += 1
	for i in 4:
		var b := _color_modal.find_child("Color%d" % i, true, false) as Button
		b.text = "%s\n%d in hand" % [CardData.COLOR_NAMES[i].to_upper(), counts[i]]
		b.visible = allowed.has(i)
	_color_modal.visible = true
	_color_modal.modulate.a = 0.0
	create_tween().tween_property(_color_modal, "modulate:a", 1.0, 0.15)
	var chosen: int = await _color_chosen
	_color_modal.visible = false
	_modal = false
	return chosen

# ---------- Turn flow ----------

func _intro() -> void:
	_busy = true
	_set_status("Shuffling...", UIKit.TEXT_MUTED)
	var attempt: int = enemy.get("attempt", 1)
	if attempt > 1:
		_log_line("[color=#e5484d][b]Rematch![/b][/color] Attempt %d against [b]%s[/b]." % [attempt, enemy.name])
	else:
		_log_line("[b]%s[/b] challenges you!" % enemy.name)
	var total := maxi(state.hands[P].size(), state.hands[E].size())
	for i in total:
		for side in 2:
			if i < state.hands[side].size():
				var card: CardData = state.hands[side][i]
				var v := _spawn(card, _deck_pos(side), false)
				_views[card] = v
				_hand_views[side].append(v)
				if side == P:
					_flip_later(v, true, 0.2)
				_layout_hands()
		Sfx.play("card", 1.0 + i * 0.03)
		await _wait(0.09)
	var top := _spawn(state.top_card, _deck_pos(P), false)
	_send_to_pile(top, true)
	Sfx.play("play")
	_sync_hands()
	_update_ring_now()
	await _wait(0.5)
	_busy = false
	_loop()

func _update_ring_now() -> void:
	_ring.target_color = UIKit.card_color(state.active_color)

# _loop
# DESCRIPTION: Main turn loop. Each turn applies start-of-turn abilities, then waits for a move.
func _loop() -> void:
	while not _finished and is_inside_tree():
		var side := state.current
		var start := state.begin_turn(side)
		if state.total_turns() == BattleState.TURN_WARNING:
			_float_text("%d TURNS LEFT!" % (BattleState.TURN_LIMIT - BattleState.TURN_WARNING), _center() + Vector2(0, -120), UIKit.DANGER, 48)
			_log_line("[color=#e5484d][b]Time is running out![/b][/color] At turn %d the smaller hand wins." % BattleState.TURN_LIMIT)
		for t in start.texts:
			_float_text(t, _center() + Vector2(0, -120), UIKit.GOLD, 46)
		if start.color_shift >= 0:
			_log_line("[color=#f5c542]Chroma Shift![/color] The colour is now %s." % CardData.COLOR_NAMES[start.color_shift])
			Sfx.play("power")
			_refresh_info()
			await _wait(0.6)
		if start.heal > 0:
			RunState.heal(start.heal)
			Sfx.play("heal")
			_float_text("+%d HP  (Clockwork)" % start.heal, Vector2(size.x / 2.0 - 220, size.y - 300), UIKit.SUCCESS, 30)
		if not start.forced.is_empty():
			_log_line("[color=#e5484d]House Tax:[/color] you draw a card.")
			Sfx.play("card")
			_sync_hands()
			await _wait(0.6)
		_bonus_turn = start.bonus
		if side == P:
			await _player_turn()
		else:
			await _enemy_turn()
		if not is_inside_tree():
			return
		if RunState.is_dead():
			_finished = true
			await _wait(0.6)
			router.battle_lost(enemy)
			return
		var w := state.winner()
		if w >= 0:
			await _finish(w)
			return
		state.end_turn()

func _player_turn() -> void:
	_drawn_card = null
	_dos_called = RunState.has_charm("megaphone")
	if state.playable_cards(P).is_empty() and not state.can_draw(P):
		_set_status("No moves - your turn passes", UIKit.TEXT_MUTED)
		state.note_stuck()
		await _wait(1.0)
		return
	_awaiting = true
	_set_status("Bonus turn!" if _bonus_turn else "Your turn", UIKit.GOLD if _bonus_turn else UIKit.SUCCESS)
	_refresh_controls()
	await _player_done
	_awaiting = false
	_drawn_card = null
	_refresh_controls()

func _enemy_turn() -> void:
	_set_status("%s takes a bonus turn..." % enemy.name if _bonus_turn else "%s is thinking..." % enemy.name, UIKit.DANGER)
	await _wait(0.7 + randf() * 0.4)
	var choice := EnemyAI.choose(state, E, enemy.style)
	if choice.is_empty():
		if not state.can_draw(E):
			state.note_stuck()
			_log_line("%s can't move." % enemy.name)
			await _wait(0.4)
			return
		var card := state.draw_one(E)
		Sfx.play("card")
		_sync_hands()
		await _wait(0.55)
		if state.can_play(card, E):
			choice = {"card": card, "color": EnemyAI.color_for(state.hands[E], card)}
		else:
			_log_line("%s drew a card." % enemy.name)
			return
	await _resolve_play(E, choice.card, choice.color)

# _resolve_play
# DESCRIPTION: Applies a play through the rules engine and animates all consequences.
func _resolve_play(side: int, card: CardData, color: int) -> void:
	var v: CardView = _views.get(card)
	var res := state.play(side, card, color)
	if v == null:
		v = _spawn(card, _deck_pos(side), true)
	_views.erase(card)
	_hand_views[side].erase(v)
	_send_to_pile(v, true)
	v.queue_redraw()
	Sfx.play("play")
	var who: String = "You" if side == P else enemy.name
	var line := "%s played %s" % [who, _card_bb(card)]
	if card.is_wild() or card.is_dual():
		line += " → %s" % CardData.COLOR_NAMES[card.chosen_color]
	if res.mirrored >= 0:
		line += " (copying %s)" % CardData.TYPE_NAMES[res.mirrored]
	_log_line(line + ".")
	if side == P:
		RunState.stats.cards_played += 1
	_refresh_info()
	await _wait(0.28)

	var target_pos := Vector2(size.x / 2.0, _hand_y(res.draw_target) + (-150.0 if res.draw_target == P else 140.0))
	for t in res.texts:
		var col := UIKit.GOLD if side == P else UIKit.DANGER
		_float_text(t, _center() + Vector2(0, -130) if not t.begins_with("+") else target_pos, col, 70 if t.begins_with("+") else 54)
	if res.blocked:
		_float_text("GLOVES BLOCKED 2", _center() + Vector2(0, 140), UIKit.SUCCESS, 34)
	if res.gold > 0:
		RunState.gain_gold(res.gold)
		Sfx.play("coin")
		_float_text("+%d gold" % res.gold, Vector2(size.x / 2.0 + 220, size.y - 300), UIKit.GOLD, 32)
	if res.heal > 0:
		RunState.heal(res.heal)
		Sfx.play("heal")
		_float_text("+%d HP" % res.heal, Vector2(size.x / 2.0 - 220, size.y - 300), UIKit.SUCCESS, 32)
	if res.hp_loss > 0:
		RunState.take_damage(res.hp_loss)
		Sfx.play("hurt")
		_float_text("-%d HP  (Thorns)" % res.hp_loss, Vector2(size.x / 2.0 - 220, size.y - 300), UIKit.DANGER, 32)
	if not res.discarded.is_empty():
		_log_line("%s discarded %d more card(s)." % [who, res.discarded.size()])
	if res.swapped:
		_log_line("[color=#f5c542]Hands swapped![/color]")
		Sfx.play("power")
	if not res.gifted.is_empty():
		_log_line("%s gifted %d card%s." % [who, res.gifted.size(), "" if res.gifted.size() == 1 else "s"])
		Sfx.play("power")
	if res.extra_turns > 1:
		_log_line("%s take%s %d extra turns." % [who, "" if side == P else "s", res.extra_turns])
	if not res.draws.is_empty():
		var victim := "You draw" if res.draw_target == P else "%s draws" % enemy.name
		_log_line("%s %d." % [victim, res.draws.size()])
		if res.draw_target == P:
			_shake(10.0)
			Sfx.play("hurt", 1.2, -4.0)
		else:
			_avatar.hit()
	_sync_hands()
	if not res.draws.is_empty() or res.swapped or not res.discarded.is_empty() or not res.gifted.is_empty():
		await _wait(0.55)
	if state.hands[side].size() == 1 and not res.swapped:
		await _dos_check(side)
	await _wait(0.25)

# _dos_check
# DESCRIPTION: DOS! calling and catching for both sides.
func _dos_check(side: int) -> void:
	if side == P:
		if _dos_called:
			if RunState.has_charm("megaphone"):
				_float_text("DOS!", Vector2(size.x / 2.0, size.y - 330), UIKit.GOLD, 60)
				Sfx.play("call")
			return
		await _wait(0.35)
		if randf() < float(enemy.catch):
			_float_text("CAUGHT!  +2", Vector2(size.x / 2.0, size.y - 330), UIKit.DANGER, 60)
			_log_line("[color=#e5484d]%s caught you without calling DOS! Draw 2.[/color]" % enemy.name)
			state.penalize(P, 2)
			Sfx.play("hurt")
			_shake(14.0)
			_sync_hands()
			await _wait(0.5)
		else:
			_float_text("Phew... nobody noticed", Vector2(size.x / 2.0, size.y - 330), UIKit.TEXT_MUTED, 30)
	else:
		if randf() < float(enemy.dos_call):
			_float_text("DOS!", Vector2(size.x / 2.0, _hand_y(E) + 150), UIKit.DANGER, 60)
			_log_line("%s calls [b]DOS![/b]" % enemy.name)
			Sfx.play("call", 0.8)
			return
		_log_line("%s forgot to call DOS!..." % enemy.name)
		var caught: bool = await _catch_window(2.4)
		if caught:
			_float_text("CAUGHT!  +2", Vector2(size.x / 2.0, _hand_y(E) + 150), UIKit.GOLD, 60)
			_log_line("[color=#f5c542]You caught %s! They draw 2.[/color]" % enemy.name)
			state.penalize(E, 2)
			_avatar.hit()
			Sfx.play("power")
			_sync_hands()
			await _wait(0.5)

func _catch_window(seconds: float) -> bool:
	_catch_open = true
	_catch_button.visible = true
	var t := Timer.new()
	t.one_shot = true
	add_child(t)
	t.timeout.connect(func():
		if _catch_open:
			_catch_open = false
			_catch_button.visible = false
			_catch_resolved.emit(false))
	t.start(seconds)
	var caught: bool = await _catch_resolved
	t.queue_free()
	return caught

# ---------- Ending ----------

func _finish(winner: int) -> void:
	_finished = true
	_awaiting = false
	_refresh_controls()
	await _wait(0.4)
	var won := winner == P
	_set_status("Victory!" if won else "Defeat", UIKit.GOLD if won else UIKit.DANGER)
	var panel := UIKit.panel(26)
	panel.custom_minimum_size = Vector2(620, 0)
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 500
	layer.add_child(UIKit.dimmer(0.6))
	layer.add_child(UIKit.centered(panel))
	var col := UIKit.vbox(14)
	panel.add_child(col)
	var button: Button
	if won:
		Sfx.play("win")
		var leftover: int = mini(state.hands[E].size(), 10)
		var bust: bool = state.hands[E].size() >= BattleState.BUST_LIMIT
		var gold: int = int(enemy.gold) + leftover * 2 + (10 if RunState.has_charm("lucky_coin") else 0)
		RunState.gain_gold(gold)
		col.add_child(UIKit.title("VICTORY", 84, UIKit.GOLD))
		var why := "%s went BUST holding %d cards!" % [enemy.name, state.hands[E].size()] if bust else "You emptied your hand. %s was left holding %d card%s." % [enemy.name, leftover, "" if leftover == 1 else "s"]
		if state.time_up() and not state.hands[P].is_empty():
			why = "Time! You held fewer cards than %s when the clock ran out." % enemy.name
		col.add_child(UIKit.label(why, 20, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
		var gl := UIKit.hbox(10)
		gl.alignment = BoxContainer.ALIGNMENT_CENTER
		gl.add_child(Glyph.new("coin", UIKit.GOLD, 36))
		gl.add_child(UIKit.label("+%d gold" % gold, 30, UIKit.GOLD, true))
		col.add_child(gl)
		button = UIKit.button("COLLECT REWARDS", "AccentButton", Vector2(320, 60))
		button.pressed.connect(func(): router.battle_won(enemy, gold))
	else:
		Sfx.play("lose")
		var held: int = state.hands[P].size()
		var dmg: int = int(enemy.attack) * mini(held, 10)
		if RunState.has_charm("thick_skin"):
			dmg = int(ceil(dmg * 0.7))
		var had_phoenix := RunState.has_charm("phoenix_feather")
		RunState.take_damage(dmg)
		_shake(18.0)
		col.add_child(UIKit.title("DEFEAT", 84, UIKit.DANGER))
		var lost_why := "You went BUST holding %d cards!" % held if held >= BattleState.BUST_LIMIT else "%s emptied their hand first. You were holding %d card%s." % [enemy.name, held, "" if held == 1 else "s"]
		if state.time_up() and not state.hands[E].is_empty() and held < BattleState.BUST_LIMIT:
			lost_why = "Time! You were holding %d cards, more than %s, when the clock ran out." % [held, enemy.name]
		col.add_child(UIKit.label(lost_why, 20, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
		var hl := UIKit.hbox(10)
		hl.alignment = BoxContainer.ALIGNMENT_CENTER
		hl.add_child(Glyph.new("heart", UIKit.DANGER, 36))
		hl.add_child(UIKit.label("-%d HP" % dmg, 30, UIKit.DANGER, true))
		col.add_child(hl)
		if had_phoenix and not RunState.has_charm("phoenix_feather"):
			col.add_child(UIKit.label("The Phoenix Feather burns away... you rise again!", 20, UIKit.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
		if not RunState.is_dead():
			col.add_child(UIKit.label("%s still blocks the way. You must win to move on." % enemy.name, 18, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
		button = UIKit.button("TRY AGAIN" if not RunState.is_dead() else "ACCEPT FATE", "DangerButton" if RunState.is_dead() else "AccentButton", Vector2(320, 60))
		button.pressed.connect(_after_loss)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(UIKit.spacer(0, 6))
	col.add_child(button)
	panel.pivot_offset = Vector2(310, 150)
	layer.modulate.a = 0.0
	add_child(layer)
	var tw := create_tween()
	tw.tween_property(layer, "modulate:a", 1.0, 0.25)

func _after_loss() -> void:
	router.battle_lost(enemy)


# ---------- Active colour ring ----------
class ActiveColorRing extends Control:
	var target_color := Color.WHITE
	var _color := Color.WHITE
	var _t := 0.0

	func _init() -> void:
		size = Vector2(300, 300)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		_color = _color.lerp(target_color, minf(1.0, delta * 6.0))
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var pulse := 0.5 + 0.5 * sin(_t * 2.5)
		# Pixel frame around the pile in the active colour, with four marker blocks circling it.
		var outer := Rect2(c - Vector2(125, 140), Vector2(250, 280))
		draw_rect(outer, Color(_color, 0.07 + 0.04 * pulse))
		draw_rect(outer, Color(_color, 0.4 + 0.25 * pulse), false, 6.0)
		draw_rect(outer.grow(10), Color(_color, 0.12), false, 4.0)
		for i in 4:
			var t := fmod(_t * 0.15 + i * 0.25, 1.0)
			var p := _perimeter_point(outer, t)
			draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), _color)

	func _perimeter_point(r: Rect2, t: float) -> Vector2:
		var per := 2.0 * (r.size.x + r.size.y)
		var d := t * per
		if d < r.size.x:
			return r.position + Vector2(d, 0)
		d -= r.size.x
		if d < r.size.y:
			return r.position + Vector2(r.size.x, d)
		d -= r.size.y
		if d < r.size.x:
			return r.end - Vector2(d, 0)
		d -= r.size.x
		return Vector2(r.position.x, r.end.y - d)
