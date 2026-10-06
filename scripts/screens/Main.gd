# ==========================================
# FILE: Main.gd
# DESCRIPTION: Root of the game. Owns the background, HUD, overlays and screen transitions, and routes
#              between screens (title -> map -> battle/shop/rest/event -> rewards -> ... -> end).
# VERSION: v0.100
# ==========================================
extends Control

const FELT := preload("res://shaders/felt.gdshader")

const MOODS := {
	"title": [Color(0.17, 0.1, 0.26), Color(0.03, 0.02, 0.06)],
	"map": [Color(0.1, 0.17, 0.27), Color(0.02, 0.04, 0.08)],
	"battle": [Color(0.1, 0.32, 0.28), Color(0.02, 0.07, 0.08)],
	"elite": [Color(0.3, 0.12, 0.14), Color(0.05, 0.02, 0.03)],
	"boss": [Color(0.32, 0.08, 0.1), Color(0.04, 0.01, 0.02)],
	"shop": [Color(0.27, 0.19, 0.1), Color(0.05, 0.03, 0.02)],
	"rest": [Color(0.24, 0.14, 0.07), Color(0.04, 0.02, 0.02)],
	"event": [Color(0.14, 0.12, 0.27), Color(0.02, 0.02, 0.06)],
	"reward": [Color(0.22, 0.2, 0.08), Color(0.04, 0.04, 0.02)],
}

var _bg: ColorRect
var _bg_mat: ShaderMaterial
var _screen_root: Control
var _hud: Hud
var _overlay: Control
var _fade: ColorRect
var _current: Control
var _pause: Control
var _busy := false

func _ready() -> void:
	theme = UIKit.build_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = FELT
	_bg.material = _bg_mat
	add_child(_bg)

	_screen_root = Control.new()
	_screen_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen_root)

	_hud = Hud.new()
	_hud.visible = false
	_hud.deck_pressed.connect(func(): open_deck("YOUR DECK", RunState.deck))
	_hud.menu_pressed.connect(toggle_pause)
	_hud.z_index = 400
	add_child(_hud)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.z_index = 1000
	add_child(_overlay)

	_fade = ColorRect.new()
	_fade.color = Color(0.01, 0.01, 0.02, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.process_mode = Node.PROCESS_MODE_ALWAYS
	_fade.z_index = 2000
	add_child(_fade)

	resized.connect(func(): _bg_mat.set_shader_parameter("rect_size", size))
	_bg_mat.set_shader_parameter("rect_size", size)
	_set_mood("title", true)
	show_title()

# ---------- Screen management ----------

func _set_mood(mood: String, instant: bool = false) -> void:
	var cols: Array = MOODS.get(mood, MOODS.battle)
	if instant:
		_bg_mat.set_shader_parameter("center_color", cols[0])
		_bg_mat.set_shader_parameter("edge_color", cols[1])
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(c): _bg_mat.set_shader_parameter("center_color", c), _bg_mat.get_shader_parameter("center_color"), cols[0], 0.6)
	tw.tween_method(func(c): _bg_mat.set_shader_parameter("edge_color", c), _bg_mat.get_shader_parameter("edge_color"), cols[1], 0.6)

# _swap_to
# DESCRIPTION: Fades to black, replaces the active screen, then fades back in.
func _swap_to(screen: Control, show_hud: bool, mood: String) -> void:
	while _busy:
		await get_tree().process_frame
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var out := create_tween()
	out.tween_property(_fade, "color:a", 1.0, 0.0 if _current == null else 0.2)
	await out.finished
	if _current != null:
		_current.queue_free()
	for child in _overlay.get_children():
		child.queue_free()
	get_tree().paused = false
	_pause = null
	screen.set("router", self)
	_screen_root.add_child(screen)
	_current = screen
	_hud.visible = show_hud
	_hud.refresh()
	_set_mood(mood, true)
	var back := create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.3)
	await back.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func show_title() -> void:
	_swap_to(TitleScreen.new(), false, "title")

func start_run() -> void:
	RunState.new_run()
	show_map()

func show_map() -> void:
	_swap_to(MapScreen.new(), true, "map")

# enter_node
# DESCRIPTION: Called by the map when the player picks a node.
func enter_node(id: int) -> void:
	RunState.enter_node(id)
	var node: Dictionary = RunState.map_nodes[id]
	match node.type:
		"battle", "elite", "boss":
			var screen := BattleScreen.new()
			screen.enemy = Enemies.pick(RunState.act, node.type)
			_swap_to(screen, true, node.type)
		"shop":
			_swap_to(ShopScreen.new(), true, "shop")
		"rest":
			_swap_to(RestScreen.new(), true, "rest")
		"event":
			_swap_to(EventScreen.new(), true, "event")
		"treasure":
			var gold := randi_range(20, 35)
			RunState.gain_gold(gold)
			show_reward({"title": "TREASURE", "subtitle": "A dusty chest, left behind by a careless gambler.", "gold": gold, "cards": 0, "charms": Charms.random_unowned(RunState.charms, 2)})

# battle_won
# DESCRIPTION: Builds the reward screen for the beaten opponent.
func battle_won(enemy: Dictionary, gold: int) -> void:
	RunState.stats.battles_won += 1
	var params := {"title": "VICTORY", "subtitle": "%s has been defeated." % enemy.name, "gold": gold, "cards": 3, "card_bonus": 0.0, "charms": []}
	match enemy.kind:
		"elite":
			RunState.stats.elites += 1
			params.card_bonus = 0.15
			params.charms = Charms.random_unowned(RunState.charms, 2)
		"boss":
			RunState.stats.bosses += 1
			params.title = "BOSS DEFEATED"
			params.card_bonus = 0.35
			params.charms = Charms.random_unowned(RunState.charms, 3)
			params.boss = true
	if enemy.kind == "boss" and RunState.act >= RunState.ACTS:
		show_end(true)
		return
	show_reward(params)

func battle_lost() -> void:
	if RunState.is_dead():
		show_end(false)
	else:
		show_map()

func show_reward(params: Dictionary) -> void:
	var screen := RewardScreen.new()
	screen.params = params
	_swap_to(screen, true, "reward")

# reward_done
# DESCRIPTION: After rewards: continue the map, or advance to the next act after a boss.
func reward_done(params: Dictionary) -> void:
	if params.get("boss", false):
		RunState.next_act()
	show_map()

func show_end(victory: bool) -> void:
	RunState.end_run(victory)
	var screen := EndScreen.new()
	screen.victory = victory
	_swap_to(screen, false, "title" if victory else "boss")

# ---------- Overlays ----------

# open_deck
# DESCRIPTION: Opens the deck viewer. Await `viewer.closed` to get the chosen card (or null).
func open_deck(title_text: String, cards: Array, selectable: bool = false, subtitle: String = "", cancellable: bool = true) -> DeckViewer:
	var viewer := DeckViewer.new().setup(title_text, cards, selectable, subtitle, cancellable)
	_overlay.add_child(viewer)
	return viewer

func has_overlay() -> bool:
	return _overlay.get_child_count() > 0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and RunState.in_run and _hud.visible:
		get_viewport().set_input_as_handled()
		toggle_pause()

# toggle_pause
# DESCRIPTION: Pause menu with settings and the option to abandon the run.
func toggle_pause() -> void:
	if _pause != null:
		_pause.queue_free()
		_pause = null
		get_tree().paused = false
		return
	get_tree().paused = true
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(UIKit.dimmer(0.75))
	var panel := UIKit.panel(24)
	panel.custom_minimum_size = Vector2(460, 0)
	_pause.add_child(UIKit.centered(panel))
	var col := UIKit.vbox(14)
	panel.add_child(col)
	col.add_child(UIKit.title("PAUSED", 52, UIKit.GOLD))
	col.add_child(UIKit.spacer(0, 8))

	var resume := UIKit.button("RESUME", "AccentButton")
	resume.pressed.connect(toggle_pause)
	col.add_child(resume)

	var sound := UIKit.button("")
	var sound_text := func(): sound.text = "SOUND: %s" % ("ON" if RunState.sound_on else "OFF")
	sound_text.call()
	sound.pressed.connect(func():
		RunState.sound_on = not RunState.sound_on
		RunState.save_meta()
		sound_text.call())
	col.add_child(sound)

	var speed := UIKit.button("")
	var speed_text := func(): speed.text = "GAME SPEED: %s" % ("FAST" if RunState.fast_mode else "NORMAL")
	speed_text.call()
	speed.pressed.connect(func():
		RunState.fast_mode = not RunState.fast_mode
		RunState.save_meta()
		speed_text.call())
	col.add_child(speed)

	var deck := UIKit.button("VIEW DECK")
	deck.pressed.connect(func(): open_deck("YOUR DECK", RunState.deck))
	col.add_child(deck)

	col.add_child(UIKit.spacer(0, 8))
	var abandon := UIKit.button("ABANDON RUN", "DangerButton")
	abandon.pressed.connect(func():
		RunState.end_run(false)
		show_title())
	col.add_child(abandon)
	var quit := UIKit.button("QUIT TO DESKTOP", "GhostButton")
	quit.pressed.connect(func(): get_tree().quit())
	col.add_child(quit)
	_overlay.add_child(_pause)
