# ==========================================
# FILE: sim_battles.gd
# DESCRIPTION: Headless rules check. Plays many AI-vs-AI battles and verifies no cards are lost
#              and every battle terminates. Run with:
#              godot --headless -s res://tests/sim_battles.gd
# VERSION: v0.100
# ==========================================
extends SceneTree

const GAMES := 400
const MAX_TURNS := 3000

func _initialize() -> void:
	var wins := [0, 0]
	var failures := 0
	var total_turns := 0
	var all_charms: Array = Charms.DATA.keys()
	for g in GAMES:
		var act := (g % 3) + 1
		var enemy := Enemies.pick(act, ["battle", "elite", "boss"][g % 3])
		var deck := CardFactory.starter_deck()
		for i in g % 8:
			deck.append(CardFactory.reward_card(act))
		# Make sure every wacky card gets exercised.
		for i in 3:
			deck.append(CardFactory.trick_card())
		deck.append(CardFactory.wild(CardData.Type.WILD_SWAP))
		var s := BattleState.new()
		var charms: Array = all_charms.slice(0, g % all_charms.size())
		s.setup(deck, CardFactory.enemy_deck(enemy.deck, act, enemy.kind), charms, enemy.abilities, 7, enemy.hand)
		var expected := s.total_cards()
		var turns := 0
		while s.winner() < 0 and turns < MAX_TURNS:
			turns += 1
			var side := s.current
			s.begin_turn(side)
			if s.winner() >= 0:
				break
			var choice := EnemyAI.choose(s, side, "smart" if side == 0 else enemy.style)
			if choice.is_empty():
				var drawn := s.draw_one(side)
				if drawn == null:
					s.note_stuck()
				elif s.can_play(drawn, side):
					choice = {"card": drawn, "color": EnemyAI.color_for(s.hands[side], drawn)}
			if not choice.is_empty():
				s.play(side, choice.card, choice.color)
				if randf() < 0.01:
					s.penalize(side, 2)
			if s.total_cards() != expected:
				push_error("Card count mismatch in game %d: %d != %d" % [g, s.total_cards(), expected])
				failures += 1
				break
			s.end_turn()
		if turns >= MAX_TURNS:
			push_error("Game %d did not finish" % g)
			failures += 1
		else:
			wins[s.winner()] += 1
		total_turns += turns
	# Every opponent in the roster, several times each, so every deck archetype and ability is covered.
	var roster_games := 0
	for act in Enemies.ROSTER:
		for kind in Enemies.ROSTER[act]:
			for def in Enemies.ROSTER[act][kind]:
				for rep in 4:
					var enemy: Dictionary = def.duplicate(true)
					enemy["kind"] = kind
					var s := BattleState.new()
					s.setup(CardFactory.starter_deck(), CardFactory.enemy_deck(enemy.deck, act, kind), [], enemy.abilities, 7, enemy.hand)
					var expected := s.total_cards()
					var turns := 0
					while s.winner() < 0 and turns < MAX_TURNS:
						turns += 1
						var side := s.current
						s.begin_turn(side)
						if s.winner() >= 0:
							break
						var choice := EnemyAI.choose(s, side, "smart" if side == 0 else enemy.style)
						if choice.is_empty():
							var drawn := s.draw_one(side)
							if drawn == null:
								s.note_stuck()
							elif s.can_play(drawn, side):
								choice = {"card": drawn, "color": EnemyAI.color_for(s.hands[side], drawn)}
						if not choice.is_empty():
							s.play(side, choice.card, choice.color)
						if s.total_cards() != expected:
							push_error("Card count mismatch vs %s" % enemy.name)
							failures += 1
							break
						s.end_turn()
					if turns >= MAX_TURNS:
						push_error("Battle vs %s did not finish" % enemy.name)
						failures += 1
					roster_games += 1
	print("Roster check: %d battles against every opponent" % roster_games)
	print("Simulated %d battles: player(smart) %d, enemy %d, avg turns %.1f, failures %d" % [GAMES, wins[0], wins[1], float(total_turns) / GAMES, failures])
	# Map sanity: every non-boss node must lead somewhere and every node above row 0 must be reachable.
	for i in 200:
		var nodes := MapGen.generate(1)
		for n in nodes:
			if n.type != "boss" and n.next.is_empty():
				push_error("Dead-end map node")
				failures += 1
			if n.row > 0:
				var reachable := false
				for p in nodes:
					if p.next.has(n.id):
						reachable = true
				if not reachable:
					push_error("Unreachable map node")
					failures += 1
	# Route rules: on any path, at most 2 shops, at most 2 rests and exactly 1 treasure,
	# and never two specials (shop/rest/treasure) back to back.
	var specials := ["shop", "rest", "treasure"]
	for i in 200:
		var nodes := MapGen.generate(1)
		var best := {}   # id -> {max counts along any path to here, min elites}
		for n in nodes:
			var counts := {"shop": 0, "rest": 0, "treasure": 0, "elite_min": 0}
			var parents := nodes.filter(func(p): return p.next.has(n.id))
			if not parents.is_empty():
				counts = {"shop": 0, "rest": 0, "treasure": 0, "elite_min": 999}
				for p in parents:
					var pc: Dictionary = best[p.id]
					for k in ["shop", "rest", "treasure"]:
						counts[k] = maxi(counts[k], pc[k])
					counts.elite_min = mini(counts.elite_min, pc.elite_min)
					if specials.has(p.type) and specials.has(n.type):
						push_error("Back-to-back specials: %s -> %s" % [p.type, n.type])
						failures += 1
			if counts.has(n.type):
				counts[n.type] += 1
			if n.type == "elite":
				counts.elite_min += 1
			best[n.id] = counts
		var boss: Dictionary = best[nodes.back().id]
		if boss.shop > 2 or boss.rest > 2 or boss.treasure != 1:
			push_error("Route rule broken: %s" % boss)
			failures += 1
	print("Map check done, failures %d" % failures)
	# Trickster's Pact generation: every rarity must produce a valid card.
	for i in 300:
		var c := CardFactory.card_of_rarity(i % 3, true)
		if c == null or c.title() == "":
			push_error("Bad trick-weighted card")
			failures += 1
	quit(1 if failures > 0 else 0)
