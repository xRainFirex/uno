# ==========================================
# FILE: RestScreen.gd
# DESCRIPTION: Campfire: either rest to heal, or enchant a card in your deck.
# VERSION: v0.100
# ==========================================
class_name RestScreen
extends Control

var router: Node
var _options: Array[Button] = []
var _result: Label
var _continue: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var col := UIKit.vbox(16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = Hud.HEIGHT
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var fire := Glyph.new("flame", Color(1.0, 0.6, 0.25), 120)
	fire.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(fire)
	col.add_child(UIKit.title("CAMPFIRE", 72, Color(1.0, 0.72, 0.4)))
	col.add_child(UIKit.label("The fire crackles. You have time for one thing.", 21, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.spacer(0, 16))

	var row := UIKit.hbox(30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var heal := int(ceil(RunState.max_hp * 0.3))
	var rest := _option("heart", UIKit.DANGER, "REST", "Heal %d HP." % heal)
	rest.disabled = RunState.hp >= RunState.max_hp
	rest.pressed.connect(func():
		RunState.heal(heal)
		Sfx.play("heal")
		_done("You rest by the fire and recover %d HP." % heal))
	row.add_child(rest)
	var enchant := _option("star", UIKit.GOLD, "ENCHANT", "Give a card a random enchantment:\nGilded, Barbed or Healing.")
	enchant.pressed.connect(_on_enchant)
	row.add_child(enchant)

	_result = UIKit.label("", 22, UIKit.SUCCESS, true, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_result)
	_continue = UIKit.button("CONTINUE", "AccentButton", Vector2(260, 60))
	_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue.visible = false
	_continue.pressed.connect(func(): router.show_map())
	col.add_child(_continue)

	if rest.disabled and RunState.deck.all(func(c): return c.enchant != CardData.Enchant.NONE):
		_continue.visible = true

func _option(icon: String, color: Color, title_text: String, desc: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(320, 240)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var inner := UIKit.vbox(10)
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	var g := Glyph.new(icon, color, 64)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(g)
	inner.add_child(UIKit.label(title_text, 28, UIKit.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER))
	inner.add_child(UIKit.label(desc, 17, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	_options.append(b)
	return b

func _on_enchant() -> void:
	var candidates := RunState.deck.filter(func(c): return c.enchant == CardData.Enchant.NONE)
	var viewer: DeckViewer = router.open_deck("ENCHANT A CARD", candidates, true, "Choose a card to enchant.")
	var card: CardData = await viewer.closed
	if card == null:
		return
	card.enchant = randi_range(1, CardData.Enchant.size() - 1) as CardData.Enchant
	RunState.changed.emit()
	Sfx.play("power")
	_done("%s\n%s" % [card.title(), CardData.ENCHANT_DESCRIPTIONS[card.enchant]])

func _done(text: String) -> void:
	for b in _options:
		b.disabled = true
	_result.text = text
	_continue.visible = true
