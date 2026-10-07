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
	print("Map check done, failures %d" % failures)
	quit(1 if failures > 0 else 0)
