# ==========================================
# FILE: MapScreen.gd
# DESCRIPTION: Branching act map. Pick the next node among those connected to where you are.
# VERSION: v0.100
# ==========================================
class_name MapScreen
extends Control

const NODE_STYLE := {
	"battle": {"icon": "sword", "color": Color(0.82, 0.86, 0.92), "label": "Battle"},
	"elite": {"icon": "skull", "color": Color(0.95, 0.38, 0.38), "label": "Elite"},
	"boss": {"icon": "crown", "color": Color(0.96, 0.77, 0.26), "label": "Boss"},
	"shop": {"icon": "bag", "color": Color(0.42, 0.85, 0.55), "label": "Shop"},
	"rest": {"icon": "flame", "color": Color(1.0, 0.6, 0.25), "label": "Campfire"},
	"event": {"icon": "question", "color": Color(0.62, 0.58, 1.0), "label": "Event"},
	"treasure": {"icon": "chest", "color": Color(0.96, 0.77, 0.26), "label": "Treasure"},
}

const DESCRIPTIONS := {
	"battle": "Battle: a standard opponent. Win cards and gold.",
	"elite": "Elite: a tough opponent with special rules. Drops a charm.",
	"boss": "Boss: defeat them to finish the act.",
	"shop": "Shop: buy cards and charms, or remove cards.",
	"rest": "Campfire: heal, or enchant a card.",
	"event": "Event: something unexpected...",
	"treasure": "Treasure: a free charm and some gold.",
}

var router: Node
const ROW_GAP := 118.0
const MAP_PAD_TOP := 120.0
const MAP_PAD_BOTTOM := 90.0

var _canvas: Control
var _scroll: ScrollContainer
var _content: Control
var _nodes: Dictionary = {}
var _available: Array = []
var _time := 0.0
var _locked := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_available = RunState.available_nodes()

	# The map is taller than the screen, so it lives in a vertical scroll area below the HUD.
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = Hud.HEIGHT
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_content)

	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_paths)
	_content.add_child(_canvas)

	for n in RunState.map_nodes:
		var view := MapNodeView.new(n)
		view.state = _state_of(n)
		view.tooltip_text = "Floor %d  ·  %s" % [int(n.row) + 1, DESCRIPTIONS[n.type]]
		view.pressed.connect(_on_node_pressed)
		_content.add_child(view)
		_nodes[n.id] = view

	# Act banner and legend
	var side := UIKit.vbox(6)
	side.position = Vector2(56, 120)
	add_child(side)
	side.add_child(UIKit.label("ACT %s" % ["I", "II", "III"][RunState.act - 1], 26, UIKit.GOLD, true))
	var name_label := UIKit.title(Enemies.ACT_NAMES[RunState.act - 1].to_upper(), 46)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	side.add_child(name_label)
	side.add_child(UIKit.label("Choose your path. The boss awaits at the top.", 19, UIKit.TEXT_MUTED))
	side.add_child(UIKit.label("Scroll to see the whole route.", 17, UIKit.TEXT_MUTED))
	side.add_child(UIKit.spacer(0, 30))
	for t in ["battle", "elite", "event", "shop", "rest", "treasure", "boss"]:
		var row := UIKit.hbox(12)
		row.add_child(Glyph.new(NODE_STYLE[t].icon, NODE_STYLE[t].color, 30))
		row.add_child(UIKit.label(NODE_STYLE[t].label, 20, UIKit.TEXT))
		side.add_child(row)

	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in side.get_children():
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_layout.call_deferred()
	_scroll_to_current.call_deferred()

func _state_of(n: Dictionary) -> String:
	if n.id == RunState.current_node:
		return "current"
	if RunState.visited.has(n.id):
		return "visited"
	if _available.has(n.id):
		return "available"
	return "locked"

func _content_height() -> float:
	return MAP_PAD_TOP + ROW_GAP * (MapGen.ROWS - 1) + MAP_PAD_BOTTOM

# _node_pos
# DESCRIPTION: Node centre in scroll-content coordinates. Row 0 sits at the bottom, the boss at the top.
func _node_pos(n: Dictionary) -> Vector2:
	var bottom := _content_height() - MAP_PAD_BOTTOM
	var cx := size.x * 0.56
	return Vector2(cx + (float(n.lane) - 1.5) * 220.0 + n.jx, bottom - n.row * ROW_GAP + n.jy)

# _scroll_to_current
# DESCRIPTION: Starts the view on the rows you can pick from, then eases there if needed.
func _scroll_to_current() -> void:
	var row := 0
	if not _available.is_empty():
		row = int(RunState.map_nodes[_available[0]].row)
	var target_y := _content_height() - MAP_PAD_BOTTOM - row * ROW_GAP
	var scroll_to := clampf(target_y - _scroll.size.y * 0.72, 0.0, maxf(0.0, _content_height() - _scroll.size.y))
	# Begin one row lower and glide up so the player sees where they came from.
	_scroll.scroll_vertical = int(minf(scroll_to + ROW_GAP, maxf(0.0, _content_height() - _scroll.size.y)))
	create_tween().tween_property(_scroll, "scroll_vertical", int(scroll_to), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _layout() -> void:
	_content.custom_minimum_size = Vector2(size.x - 20.0, _content_height())
	for id in _nodes:
		var view: MapNodeView = _nodes[id]
		view.position = _node_pos(RunState.map_nodes[id]) - view.size / 2.0
	_canvas.queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()

func _draw_paths() -> void:
	for n in RunState.map_nodes:
		var a := _node_pos(n)
		for nid in n.next:
			var m: Dictionary = RunState.map_nodes[nid]
			var b := _node_pos(m)
			var dir := (b - a).normalized()
			var from: Vector2 = a + dir * (_nodes[n.id].size.x / 2.0 + 6.0)
			var to: Vector2 = b - dir * (_nodes[nid].size.x / 2.0 + 6.0)
			var travelled: bool = RunState.visited.has(n.id) and RunState.visited.has(nid)
			var open: bool = n.id == RunState.current_node and _available.has(nid)
			if travelled:
				_canvas.draw_line(from, to, Color(UIKit.GOLD, 0.85), 6.0)
			elif open:
				var a2 := 0.55 + 0.35 * sin(_time * 4.0)
				_canvas.draw_dashed_line(from, to, Color(1, 1, 1, a2), 5.0, 10.0)
			else:
				_canvas.draw_dashed_line(from, to, Color(1, 1, 1, 0.14), 4.0, 8.0)

func _on_node_pressed(id: int) -> void:
	if _locked or not _available.has(id):
		return
	_locked = true
	Sfx.play("power")
	router.enter_node(id)


# ---------- Map node widget ----------
class MapNodeView extends Control:
	signal pressed(id: int)

	var node: Dictionary
	var state := "locked":
		set(v):
			state = v
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if v == "available" else Control.CURSOR_ARROW
			queue_redraw()
	var _hover := false
	var _t := 0.0

	func _init(n: Dictionary) -> void:
		node = n
		var px := 120.0 if n.type == "boss" else 74.0
		custom_minimum_size = Vector2(px, px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		mouse_entered.connect(func():
			_hover = true
			if state == "available":
				Sfx.play("hover", 1.0, -6.0))
		mouse_exited.connect(func(): _hover = false)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(node.id)

	func _process(delta: float) -> void:
		_t += delta
		if state == "available" or state == "current" or _hover or node.type == "elite" or node.type == "boss":
			queue_redraw()

	func _draw() -> void:
		var style: Dictionary = MapScreen.NODE_STYLE[node.type]
		var col: Color = style.color
		var c := size / 2.0
		var r := size.x / 2.0
		var grow := 1.0
		if state == "available":
			grow = 1.0 + 0.05 * sin(_t * 4.0) + (0.08 if _hover else 0.0)
		r *= grow
		var bg := Color(0.06, 0.08, 0.12, 0.95)
		var ring := col
		var icon_col := col
		match state:
			"locked":
				ring = Color(col, 0.3)
				icon_col = Color(col, 0.35)
			"visited":
				ring = Color(UIKit.GOLD, 0.6)
				icon_col = Color(col, 0.45)
			"available":
				var g := r * (1.25 + 0.06 * sin(_t * 4.0))
				draw_rect(Rect2(c - Vector2(g, g), Vector2(g, g) * 2.0), Color(col, 0.12 + 0.08 * sin(_t * 4.0)))
		if (node.type == "elite" or node.type == "boss") and state != "visited":
			# Dangerous nodes pulse so you can see them coming from afar.
			var pulse := 0.5 + 0.5 * sin(_t * 3.0)
			var g2 := r * (1.18 + 0.08 * pulse)
			draw_rect(Rect2(c - Vector2(g2, g2), Vector2(g2, g2) * 2.0), Color(col, 0.10 + 0.12 * pulse))
		# Square pixel tile: ink rim, coloured border, dark well, pixel icon.
		var box := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
		draw_rect(box, PixelCard.INK)
		draw_rect(box.grow(-3), ring)
		draw_rect(box.grow(-7), bg)
		Glyph.paint(self, style.icon, c, r * 0.62, icon_col)
		if state == "visited":
			draw_line(c + Vector2(-r * 0.3, 0), c + Vector2(-r * 0.05, r * 0.25), UIKit.GOLD, 6.0)
			draw_line(c + Vector2(-r * 0.05, r * 0.25), c + Vector2(r * 0.35, -r * 0.25), UIKit.GOLD, 6.0)
		if state == "current":
			var bob := sin(_t * 3.0) * 4.0
			var tip := c + Vector2(0, -r - 8 + bob)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-12, -18), tip + Vector2(12, -18)]), UIKit.GOLD)
