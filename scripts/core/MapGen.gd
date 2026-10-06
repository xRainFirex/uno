# ==========================================
# FILE: MapGen.gd
# DESCRIPTION: Generates a branching act map. Each node: {id, row, lane, type, next, jx, jy}.
# VERSION: v0.100
# ==========================================
class_name MapGen
extends RefCounted

const ROWS := 7          # rows 0..5 are regular floors, row 6 is the boss
const LANES := 4
const TREASURE_ROW := 3

static func generate(act: int) -> Array:
	var nodes: Array = []
	var rows: Array = []
	for r in ROWS - 1:
		var count := 3 if r == 0 else randi_range(2, 4)
		var lanes := range(LANES)
		lanes.shuffle()
		lanes = lanes.slice(0, count)
		lanes.sort()
		var row_ids: Array = []
		for lane in lanes:
			var node := {
				"id": nodes.size(), "row": r, "lane": lane, "type": _roll_type(r, act), "next": [],
				"jx": randf_range(-28.0, 28.0), "jy": randf_range(-14.0, 14.0),
			}
			nodes.append(node)
			row_ids.append(node.id)
		rows.append(row_ids)

	var boss := {"id": nodes.size(), "row": ROWS - 1, "lane": 1.5, "type": "boss", "next": [], "jx": 0.0, "jy": 0.0}
	nodes.append(boss)
	rows.append([boss.id])

	# Connect each node to the nearest node(s) on the next row, then make sure nothing is orphaned.
	for r in ROWS - 1:
		var here: Array = rows[r]
		var above: Array = rows[r + 1]
		for id in here:
			var n: Dictionary = nodes[id]
			var sorted := above.duplicate()
			sorted.sort_custom(func(a, b): return absf(nodes[a].lane - n.lane) < absf(nodes[b].lane - n.lane))
			_link(n, sorted[0])
			if sorted.size() > 1 and absf(nodes[sorted[1]].lane - n.lane) <= 1.0 and randf() < 0.45:
				_link(n, sorted[1])
		for id in above:
			var has_parent := false
			for p in here:
				if nodes[p].next.has(id):
					has_parent = true
					break
			if not has_parent:
				var closest: int = here[0]
				for p in here:
					if absf(nodes[p].lane - nodes[id].lane) < absf(nodes[closest].lane - nodes[id].lane):
						closest = p
				_link(nodes[closest], id)
	return nodes

static func _link(node: Dictionary, target: int) -> void:
	if not node.next.has(target):
		node.next.append(target)

static func _roll_type(row: int, _act: int) -> String:
	if row == 0:
		return "battle"
	if row == TREASURE_ROW:
		return "treasure"
	if row == ROWS - 2:
		return ["rest", "rest", "rest", "shop", "event"].pick_random()
	var weights := {"battle": 45, "event": 22, "shop": 12, "elite": 0, "rest": 0}
	if row >= 2:
		weights.elite = 16
		weights.rest = 8
	var total := 0
	for k in weights:
		total += weights[k]
	var roll := randi_range(1, total)
	for k in weights:
		roll -= weights[k]
		if roll <= 0:
			return k
	return "battle"
