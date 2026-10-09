# ==========================================
# FILE: PixelCard.gd
# DESCRIPTION: Renders cards as 26x38 pixel-art sprites (shown at 5x). Elemental suits (Ember, Tide, Moss,
#              Dusk) with corner emblems, an octagonal crest plate, chunky bitmap numerals and pixel icons.
#              Sprites are cached per card appearance.
# VERSION: v0.100
# ==========================================
class_name PixelCard
extends RefCounted

const W := 26
const H := 38
const INK := Color(0.07, 0.05, 0.1)
const PARCHMENT := Color(0.96, 0.92, 0.82)
const WILD_BODY := Color(0.17, 0.13, 0.26)
const BACK_BODY := Color(0.1, 0.12, 0.25)
const BACK_GOLD := Color(0.86, 0.68, 0.27)
const ENCHANT_COLORS := [Color.WHITE, Color(1.0, 0.8, 0.25), Color(0.75, 0.4, 1.0), Color(0.35, 0.9, 0.5)]

# 5x5 mini sprites for corner indices and suit emblems.
const MINI := {
	"ember": ["..#..", ".###.", ".###.", "#####", ".###."],
	"tide": [".....", "##...", "#.#.#", "...##", "....."],
	"moss": ["...##", "..###", ".###.", "###..", "#...."],
	"dusk": [".###.", "##...", "#....", "##...", ".###."],
	"gem": ["..#..", ".###.", "#####", ".###.", "..#.."],
	"pause": ["##.##", "##.##", "##.##", "##.##", "##.##"],
	"rev": [".#...", "#####", ".#.#.", "#####", "...#."],
	"all": ["#####", ".....", "#####", ".....", "#####"],
	"snow": ["#.#.#", ".###.", "#####", ".###.", "#.#.#"],
	"gift": ["##.##", "..#..", "#####", "#.#.#", "#####"],
	"chain": ["##...", "#.##.", ".#.#.", ".##.#", "...##"],
	"mirror": ["#...#", "##.##", "#.#.#", "##.##", "#...#"],
	"swap": [".#...", "###.#", ".#.#.", "#.###", "...#."],
}
const SUIT_MINI := ["ember", "tide", "moss", "dusk"]
# 6x6 bold symbols for the +2 / +4 / x2 centre labels.
const BOLD := {
	"+": ["..##..", "..##..", "######", "######", "..##..", "..##.."],
	"x": ["##..##", "######", ".####.", ".####.", "######", "##..##"],
}
# 9x11 card-back letter.
const SIGIL_Q := [
	"..#####..", ".##...##.", "##.....##", "##.....##", "##.....##", "##.....##",
	"##..##.##", ".##..###.", "..######.", "......##.", ".......##",
]

static var _cache := {}

static func texture_for(card: CardData, face_up: bool) -> ImageTexture:
	var key := "back"
	if face_up and card != null:
		key = "%d|%d|%d|%d|%d|%d" % [card.card_color, card.second_color, card.type, card.value, card.enchant, card.chosen_color]
	if not _cache.has(key):
		var pc := PixelCanvas.new(W, H)
		if key == "back":
			_draw_back(pc)
		else:
			_draw_face(pc, card)
		_cache[key] = pc.texture()
	return _cache[key]

# ---------- Shared pieces ----------

static func _shape(pc: PixelCanvas, frame: Color) -> void:
	# Ink outline with clipped corners, then a 2px frame.
	for y in H:
		for x in W:
			var corner := (x == 0 or x == W - 1) and (y == 0 or y == H - 1)
			if not corner:
				pc.plot(x, y, INK)
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			pc.plot(x, y, frame)
	# Bevel: light top/left edge, dark bottom/right edge.
	for x in range(1, W - 1):
		pc.plot(x, 1, frame.lightened(0.3))
		pc.plot(x, H - 2, frame.darkened(0.3))
	for y in range(1, H - 1):
		pc.plot(1, y, frame.lightened(0.3))
		pc.plot(W - 2, y, frame.darkened(0.3))

static func _plate(pc: PixelCanvas, fill: Color) -> void:
	# Octagonal crest plate (x 5..20, y 9..28) with an ink rim.
	for pass_i in 2:
		var grow := 1 if pass_i == 0 else 0
		var col := INK if pass_i == 0 else fill
		var x0 := 5 - grow
		var x1 := 20 + grow
		var y0 := 9 - grow
		var y1 := 28 + grow
		for y in range(y0, y1 + 1):
			var inset := maxi(0, maxi(3 - (y - y0), 3 - (y1 - y)))
			for x in range(x0 + inset, x1 - inset + 1):
				pc.plot(x, y, col)
	# Soft inner shadow along the bottom of the plate.
	for x in range(8, 18):
		pc.plot(x, 28, fill.darkened(0.12))

static func _mini(pc: PixelCanvas, name: String, pos: Vector2i, col: Color, flip: bool = false) -> void:
	var rows: Array = MINI[name]
	for y in 5:
		for x in 5:
			var sx := 4 - x if flip else x
			var sy := 4 - y if flip else y
			if rows[sy][sx] == "#":
				pc.plot(pos.x + x, pos.y + y, col)

static func _text_shadowed(pc: PixelCanvas, text: String, center: Vector2, px: int, col: Color) -> void:
	pc.draw_text_centered(text, center + Vector2(1, 1), px, col.darkened(0.6))
	pc.draw_text_centered(text, center, px, col)

# _combo
# DESCRIPTION: Centre label for +2 / +4 / x2: a square symbol beside a tall digit (the same height as the
#              numerals on number cards), with a 1px gap so the pair sits centred on the plate.
static func _combo(pc: PixelCanvas, symbol: String, digit: String, col: Color) -> void:
	var x := 6
	var y := 11
	for pass_i in 2:
		var o := 1 if pass_i == 0 else 0
		var c := col.darkened(0.6) if pass_i == 0 else col
		var rows: Array = BOLD[symbol]
		for ry in rows.size():
			for rx in rows[ry].length():
				if rows[ry][rx] == "#":
					pc.plot(x + rx + o, y + 5 + ry + o, c)
		_glyph(pc, digit, Vector2i(x + 7 + o, y + o), 2, 3, c)

static func _glyph(pc: PixelCanvas, ch: String, pos: Vector2i, sx: int, sy: int, col: Color) -> void:
	var g: Array = PixelCanvas.FONT.get(ch, PixelCanvas.FONT["?"])
	for row in 5:
		for colx in 3:
			if g[row][colx] == "#":
				pc.draw_rect(Rect2(pos.x + colx * sx, pos.y + row * sy, sx, sy), col)

# _stamp_icon
# DESCRIPTION: Rasterises a Glyph icon into its own small canvas, outlines it, then stamps it on the card.
static func _stamp_icon(pc: PixelCanvas, icon: String, center: Vector2i, size: int, col: Color) -> void:
	var sub := PixelCanvas.new(size, size)
	Glyph.paint_shapes(sub, icon, Vector2(size, size) / 2.0, size / 2.0 - 1.5, col)
	sub.outline(INK)
	for y in size:
		for x in size:
			var p := sub.get_px(x, y)
			if p.a > 0.0:
				pc.plot(center.x - size / 2 + x, center.y - size / 2 + y, p)

# ---------- Faces ----------

static func _suit_color(c: int) -> Color:
	return UIKit.card_color(c)

static func _draw_face(pc: PixelCanvas, card: CardData) -> void:
	var wild := card.is_wild()
	var col := WILD_BODY if wild else _suit_color(card.card_color)
	var frame := col.darkened(0.4)
	if wild and card.chosen_color >= 0:
		frame = _suit_color(card.chosen_color)
	if card.enchant != CardData.Enchant.NONE:
		frame = ENCHANT_COLORS[card.enchant].darkened(0.1)
	_shape(pc, frame)

	# Body
	for y in range(3, H - 3):
		for x in range(3, W - 3):
			var c := col
			if wild:
				# Diagonal bands of all four suits.
				c = _suit_color(int((x + y) / 3) % 4).darkened(0.35)
			elif card.is_dual() and float(x - 3) / (W - 7) + float(y - 3) / (H - 7) > 1.0:
				c = _suit_color(card.second_color)
			pc.plot(x, y, c)
	for x in range(3, W - 3):
		pc.plot(x, 3, Color(1, 1, 1, 0.25))

	_plate(pc, PARCHMENT)
	var center := Vector2(12.5, 18.5)
	var ink := col.darkened(0.35) if not (wild or card.is_dual()) else INK
	match card.type:
		CardData.Type.NUMBER:
			_text_shadowed(pc, str(card.value), center, 3, ink)
		CardData.Type.DRAW_TWO:
			_combo(pc, "+", "2", ink)
		CardData.Type.WILD_DRAW_FOUR:
			_combo(pc, "+", "4", INK)
		CardData.Type.DOUBLE_DOWN:
			_combo(pc, "x", "2", ink)
		CardData.Type.SKIP:
			_stamp_icon(pc, "pause", Vector2i(13, 19), 14, col)
		CardData.Type.REVERSE:
			_stamp_icon(pc, "reverse", Vector2i(13, 19), 14, col)
		CardData.Type.DISCARD_ALL:
			_stamp_icon(pc, "cards", Vector2i(13, 19), 14, col)
		CardData.Type.FREEZE:
			_stamp_icon(pc, "snowflake", Vector2i(13, 19), 14, col)
		CardData.Type.GIFT:
			_stamp_icon(pc, "gift", Vector2i(13, 19), 14, col)
		CardData.Type.WILD:
			_stamp_icon(pc, "diamond", Vector2i(13, 19), 14, Color.WHITE)
		CardData.Type.WILD_SWAP:
			_stamp_icon(pc, "swap", Vector2i(13, 19), 16, BACK_GOLD)
		CardData.Type.WILD_CHAIN:
			_stamp_icon(pc, "chain", Vector2i(13, 19), 14, BACK_GOLD)
		CardData.Type.WILD_MIRROR:
			_stamp_icon(pc, "mirror", Vector2i(13, 19), 14, Color(0.75, 0.8, 0.95))

	# Corner indices (top-left, mirrored bottom-right) and suit emblems (top-right, mirrored bottom-left).
	var idx := _index_mini(card)
	if idx.begins_with("t:"):
		var txt := idx.substr(2)
		var tl := PixelCanvas.new(9, 7)
		tl.draw_text(txt, Vector2i(1, 1), 1, PARCHMENT)
		tl.outline(INK)
		_blit(pc, tl, Vector2i(2, 2), false)
		_blit(pc, tl, Vector2i(W - 11, H - 9), true)
	else:
		var m := PixelCanvas.new(7, 7)
		_mini(m, idx, Vector2i(1, 1), PARCHMENT)
		m.outline(INK)
		_blit(pc, m, Vector2i(2, 2), false)
		_blit(pc, m, Vector2i(W - 9, H - 9), true)
	var emblem_a: String = "gem" if wild else SUIT_MINI[card.card_color]
	var emblem_b: String = SUIT_MINI[card.second_color] if card.is_dual() else emblem_a
	var e1 := PixelCanvas.new(7, 7)
	_mini(e1, emblem_a, Vector2i(1, 1), PARCHMENT)
	e1.outline(INK)
	_blit(pc, e1, Vector2i(W - 9, 2), false)
	var e2 := PixelCanvas.new(7, 7)
	_mini(e2, emblem_b, Vector2i(1, 1), PARCHMENT)
	e2.outline(INK)
	_blit(pc, e2, Vector2i(2, H - 9), true)

	if card.enchant != CardData.Enchant.NONE:
		var mark: String = ["", "$", "!", "+"][card.enchant]
		var e := PixelCanvas.new(5, 7)
		e.draw_text(mark, Vector2i(1, 1), 1, ENCHANT_COLORS[card.enchant])
		e.outline(INK)
		_blit(pc, e, Vector2i(11, 2), false)

static func _index_mini(card: CardData) -> String:
	match card.type:
		CardData.Type.NUMBER:
			return "t:%d" % card.value
		CardData.Type.DRAW_TWO:
			return "t:+2"
		CardData.Type.WILD_DRAW_FOUR:
			return "t:+4"
		CardData.Type.DOUBLE_DOWN:
			return "t:x2"
		CardData.Type.SKIP:
			return "pause"
		CardData.Type.REVERSE:
			return "rev"
		CardData.Type.DISCARD_ALL:
			return "all"
		CardData.Type.FREEZE:
			return "snow"
		CardData.Type.GIFT:
			return "gift"
		CardData.Type.WILD_CHAIN:
			return "chain"
		CardData.Type.WILD_MIRROR:
			return "mirror"
		CardData.Type.WILD_SWAP:
			return "swap"
	return "gem"

static func _blit(dst: PixelCanvas, src: PixelCanvas, pos: Vector2i, flip: bool) -> void:
	for y in src.height:
		for x in src.width:
			var sx := src.width - 1 - x if flip else x
			var sy := src.height - 1 - y if flip else y
			var p := src.get_px(sx, sy)
			if p.a > 0.0:
				dst.plot(pos.x + x, pos.y + y, p)

# ---------- Back ----------

static func _draw_back(pc: PixelCanvas) -> void:
	_shape(pc, BACK_GOLD.darkened(0.35))
	for y in range(3, H - 3):
		for x in range(3, W - 3):
			var lattice := (x + y) % 6 == 0 or (x - y + 60) % 6 == 0
			pc.plot(x, y, BACK_BODY.lightened(0.12) if lattice else BACK_BODY)
	_plate(pc, BACK_BODY.darkened(0.3))
	# The Quietus sigil: a gold Q with a hard shadow and ink outline, flanked by small diamonds.
	var q := PixelCanvas.new(13, 15)
	for y in SIGIL_Q.size():
		for x in SIGIL_Q[y].length():
			if SIGIL_Q[y][x] == "#":
				q.plot(x + 3, y + 3, BACK_GOLD.darkened(0.55))
				q.plot(x + 2, y + 2, BACK_GOLD.lightened(0.2) if y < 3 else BACK_GOLD)
	q.outline(INK)
	_blit(pc, q, Vector2i(7, 11), false)
	for d in [Vector2i(12, 10), Vector2i(12, 26)]:
		pc.plot(d.x, d.y, BACK_GOLD)
		pc.plot(d.x + 1, d.y, BACK_GOLD)
