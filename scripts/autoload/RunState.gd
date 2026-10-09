# ==========================================
# FILE: RunState.gd
# DESCRIPTION: Autoload holding the current run (HP, gold, deck, charms, map) and lifetime stats.
# VERSION: v0.100
# ==========================================
extends Node

signal changed

const SAVE_PATH := "user://dos_meta.cfg"
const ACTS := 3
const START_HP := 50
const START_GOLD := 40

var in_run := false
var hp := START_HP
var max_hp := START_HP
var gold := START_GOLD
var deck: Array[CardData] = []
var charms: Array[String] = []
var act := 1
var map_nodes: Array = []
var current_node := -1
var visited: Array[int] = []
var removal_cost := 50
var stats := {}
var meta := {"runs": 0, "wins": 0, "best_floor": 0, "unlocked_decks": ["classic"], "deck_wins": {}}
var deck_id := "classic"

# Settings (saved with meta)
var fast_mode := false
var sound_on := true

func _ready() -> void:
	load_meta()

# new_run
# DESCRIPTION: Resets everything for a fresh run using the chosen starting deck and its perks.
func new_run(p_deck_id: String = "classic") -> void:
	in_run = true
	deck_id = p_deck_id if is_deck_unlocked(p_deck_id) else "classic"
	var def := StarterDecks.get_def(deck_id)
	max_hp = START_HP + int(def.hp)
	hp = max_hp
	gold = START_GOLD + int(def.gold)
	deck = StarterDecks.build(deck_id)
	charms = []
	for id in def.charms:
		charms.append(id)
	act = 1
	removal_cost = 50
	stats = {"battles_won": 0, "elites": 0, "bosses": 0, "cards_played": 0, "damage_taken": 0, "gold_earned": 0, "floor": 0}
	meta.runs += 1
	save_meta()
	generate_map()
	changed.emit()

func generate_map() -> void:
	map_nodes = MapGen.generate(act)
	current_node = -1
	visited = []

# floor_number
# DESCRIPTION: Overall floor counter across acts (1-based, 0 before the first node).
func floor_number() -> int:
	if current_node < 0:
		return (act - 1) * MapGen.ROWS
	return (act - 1) * MapGen.ROWS + int(map_nodes[current_node].row) + 1

func available_nodes() -> Array:
	if current_node < 0:
		return map_nodes.filter(func(n): return n.row == 0).map(func(n): return n.id)
	return map_nodes[current_node].next

func enter_node(id: int) -> void:
	current_node = id
	visited.append(id)
	stats.floor = floor_number()
	if stats.floor > meta.best_floor:
		meta.best_floor = stats.floor
		save_meta()
	changed.emit()

# next_act
# DESCRIPTION: Moves to the next act, healing half of missing HP. Returns false after the final act.
func next_act() -> bool:
	if act >= ACTS:
		return false
	act += 1
	heal(int(ceil((max_hp - hp) * 0.5)))
	generate_map()
	changed.emit()
	return true

func has_charm(id: String) -> bool:
	return charms.has(id)

func add_charm(id: String) -> void:
	if charms.has(id):
		return
	charms.append(id)
	if id == "iron_heart":
		max_hp += 12
		hp += 12
	changed.emit()

func add_card(card: CardData) -> void:
	deck.append(card.clone())
	changed.emit()

func remove_card(card: CardData) -> void:
	deck.erase(card)
	changed.emit()

func gain_gold(amount: int) -> void:
	gold += amount
	stats.gold_earned += amount
	changed.emit()

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	changed.emit()
	return true

func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	changed.emit()

func change_max_hp(amount: int) -> void:
	max_hp = maxi(1, max_hp + amount)
	hp = mini(hp, max_hp)
	changed.emit()

# take_damage
# DESCRIPTION: Applies damage. The Phoenix Feather saves you once.
func take_damage(amount: int) -> void:
	hp -= amount
	stats.damage_taken += amount
	if hp <= 0 and has_charm("phoenix_feather"):
		charms.erase("phoenix_feather")
		hp = int(max_hp * 0.5)
	changed.emit()

func is_dead() -> bool:
	return hp <= 0

func price_multiplier() -> float:
	return 0.75 if has_charm("deep_pockets") else 1.0

# end_run
# DESCRIPTION: Records the result. Winning with a deck unlocks the next one; returns its id ("" if none).
func end_run(victory: bool) -> String:
	in_run = false
	var unlocked := ""
	if victory:
		meta.wins += 1
		meta.deck_wins[deck_id] = int(meta.deck_wins.get(deck_id, 0)) + 1
		var next := StarterDecks.next_after(deck_id)
		if next != "" and not is_deck_unlocked(next):
			meta.unlocked_decks.append(next)
			unlocked = next
	save_meta()
	return unlocked

func is_deck_unlocked(id: String) -> bool:
	return meta.unlocked_decks.has(id)

func save_meta() -> void:
	var cfg := ConfigFile.new()
	for k in meta:
		cfg.set_value("meta", k, meta[k])
	cfg.set_value("settings", "fast_mode", fast_mode)
	cfg.set_value("settings", "sound_on", sound_on)
	cfg.save(SAVE_PATH)

func load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for k in meta:
		meta[k] = cfg.get_value("meta", k, meta[k])
	fast_mode = cfg.get_value("settings", "fast_mode", false)
	sound_on = cfg.get_value("settings", "sound_on", true)
