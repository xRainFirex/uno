# ==========================================
# FILE: EndScreen.gd
# DESCRIPTION: Run summary after victory or defeat.
# VERSION: v0.100
# ==========================================
class_name EndScreen
extends Control

var router: Node
var victory := false
var unlocked_deck := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Sfx.play("win" if victory else "lose")

	var panel := UIKit.panel(26)
	panel.custom_minimum_size = Vector2(720, 0)
	add_child(UIKit.centered(panel))
	var col := UIKit.vbox(14)
	panel.add_child(col)
	var icon := Glyph.new("crown" if victory else "skull", UIKit.GOLD if victory else UIKit.DANGER, 110)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	col.add_child(UIKit.title("YOU BEAT THE HOUSE" if victory else "RUN OVER", 72, UIKit.GOLD if victory else UIKit.DANGER))
	var flavour := "The Dealer folds. The House of DOS is yours." if victory else "Your luck ran out on floor %d." % RunState.floor_number()
	col.add_child(UIKit.label(flavour, 22, UIKit.TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.label("Deck: %s" % StarterDecks.get_def(RunState.deck_id).name, 18, UIKit.TEXT_MUTED, true, HORIZONTAL_ALIGNMENT_CENTER))
	if unlocked_deck != "":
		var def := StarterDecks.get_def(unlocked_deck)
		var unlock := UIKit.hbox(12)
		unlock.alignment = BoxContainer.ALIGNMENT_CENTER
		unlock.add_child(Glyph.new(def.icon, def.color, 40))
		unlock.add_child(UIKit.label("NEW DECK UNLOCKED: %s" % def.name.to_upper(), 24, UIKit.GOLD, true))
		col.add_child(unlock)
	col.add_child(UIKit.spacer(0, 10))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(grid)
	var s := RunState.stats
	var rows := [
		["Floor reached", str(RunState.floor_number())],
		["Battles won", str(s.get("battles_won", 0))],
		["Elites defeated", str(s.get("elites", 0))],
		["Bosses defeated", str(s.get("bosses", 0))],
		["Cards played", str(s.get("cards_played", 0))],
		["Gold earned", str(s.get("gold_earned", 0))],
		["Damage taken", str(s.get("damage_taken", 0))],
		["Final deck size", str(RunState.deck.size())],
	]
	for r in rows:
		grid.add_child(UIKit.label(r[0], 20, UIKit.TEXT_MUTED))
		grid.add_child(UIKit.label(r[1], 20, UIKit.TEXT, true, HORIZONTAL_ALIGNMENT_RIGHT))

	if not RunState.charms.is_empty():
		col.add_child(UIKit.spacer(0, 6))
		var charms := UIKit.hbox(8)
		charms.alignment = BoxContainer.ALIGNMENT_CENTER
		for id in RunState.charms:
			charms.add_child(CharmIcon.new(id, 44))
		col.add_child(charms)

	col.add_child(UIKit.spacer(0, 12))
	var buttons := UIKit.hbox(16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	var again := UIKit.button("NEW RUN", "AccentButton", Vector2(240, 60))
	again.pressed.connect(func(): router.show_deck_select())
	buttons.add_child(again)
	var menu := UIKit.button("MAIN MENU", "", Vector2(240, 60))
	menu.pressed.connect(func(): router.show_title())
	buttons.add_child(menu)
