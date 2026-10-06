# ==========================================
# FILE: TitleScreen.gd
# DESCRIPTION: Main menu with animated floating cards, run stats and a How to Play panel.
# VERSION: v0.100
# ==========================================
class_name TitleScreen
extends Control

var router: Node
var _floaters: Array[CardView] = []
var _time := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Decorative fan of cards behind the logo
	var deco := [
		CardData.new(CardData.CardColor.RED, CardData.Type.NUMBER, 7),
		CardData.new(CardData.CardColor.WILD, CardData.Type.WILD_DRAW_FOUR),
		CardData.new(CardData.CardColor.BLUE, CardData.Type.REVERSE),
		CardData.new(CardData.CardColor.YELLOW, CardData.Type.DRAW_TWO),
		CardData.new(CardData.CardColor.GREEN, CardData.Type.SKIP),
	]
	for i in deco.size():
		var v := CardView.new(deco[i], true)
		v.scale = Vector2(1.25, 1.25)
		add_child(v)
		_floaters.append(v)

	var col := UIKit.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	col.add_child(UIKit.spacer(0, 300))
	var logo := UIKit.title("DOS", 190, UIKit.GOLD)
	logo.add_theme_constant_override("outline_size", 26)
	logo.add_theme_color_override("font_outline_color", Color(0.25, 0.03, 0.05))
	col.add_child(logo)
	col.add_child(UIKit.label("A   C A R D   R O G U E L I K E", 24, UIKit.TEXT_MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.spacer(0, 36))

	var buttons := UIKit.vbox(14)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.custom_minimum_size.x = 340
	col.add_child(buttons)
	var start := UIKit.button("NEW RUN", "AccentButton", Vector2(0, 64))
	start.add_theme_font_size_override("font_size", 28)
	start.pressed.connect(func(): router.start_run())
	buttons.add_child(start)
	var how := UIKit.button("HOW TO PLAY")
	how.pressed.connect(_show_how_to_play)
	buttons.add_child(how)
	var quit := UIKit.button("QUIT", "GhostButton")
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)

	col.add_child(UIKit.spacer(0, 30))
	var m := RunState.meta
	var stats := "Runs  %d     ·     Victories  %d     ·     Deepest floor  %d" % [m.runs, m.wins, m.best_floor]
	col.add_child(UIKit.label(stats, 18, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))

	var ver := UIKit.label("v0.100", 14, Color(1, 1, 1, 0.25))
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-80, -34)
	add_child(ver)

func _process(delta: float) -> void:
	_time += delta
	var center := Vector2(size.x / 2.0, 250)
	for i in _floaters.size():
		var v := _floaters[i]
		var off := i - (_floaters.size() - 1) / 2.0
		var bob := sin(_time * 1.3 + i * 0.9) * 8.0
		v.rotation = off * 0.2 + sin(_time * 0.7 + i) * 0.03
		v.position = center + Vector2(off * 120.0, absf(off) * 26.0 + bob) - v.size / 2.0

func _show_how_to_play() -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(UIKit.dimmer(0.8))
	var panel := UIKit.panel(24)
	panel.custom_minimum_size = Vector2(980, 0)
	layer.add_child(UIKit.centered(panel))
	var col := UIKit.vbox(16)
	panel.add_child(col)
	col.add_child(UIKit.title("HOW TO PLAY", 46, UIKit.GOLD))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(920, 0)
	rt.add_theme_font_size_override("normal_font_size", 20)
	rt.add_theme_font_size_override("bold_font_size", 20)
	rt.text = """[b][color=#f5c542]Battles[/color][/b]  Each battle is a one-on-one card duel using classic UNO-style rules. Match the top card by [b]colour[/b], [b]number[/b] or [b]symbol[/b]. Wilds go on anything. Empty your hand to win.
[b][color=#f5c542]Your own deck[/color][/b]  You draw from your personal deck, which grows as you collect cards. Your opponent draws from theirs.
[b][color=#f5c542]Draw, then decide[/color][/b]  Click your deck (or press [b]Space[/b]) to draw. If the drawn card fits you may play it, or pass.
[b][color=#f5c542]Shout DOS![/color][/b]  With two cards left, press [b]DOS![/b] (or [b]D[/b]) before you play, or you may get caught and draw 2. Catch your opponent when they forget!
[b][color=#f5c542]Losing hurts[/color][/b]  Lose a battle and you take damage for every card left in your hand. Reach 0 HP and the run is over.
[b][color=#f5c542]The run[/color][/b]  Choose your path through three acts: battles, elites, shops, campfires, treasure and strange events. Beat each act's boss to move on.
[b][color=#f5c542]Build your deck[/color][/b]  Win new cards, buy [b]charms[/b] (passive powers), remove weak cards and [b]enchant[/b] cards (Gilded, Barbed, Healing).
[b][color=#f5c542]New cards[/color][/b]  [b]Discard All[/b] dumps every card of its colour. [b]Wild Swap[/b] trades hands with your opponent."""
	col.add_child(rt)
	var close := UIKit.button("GOT IT", "AccentButton", Vector2(220, 0))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(layer.queue_free)
	col.add_child(close)
	add_child(layer)
