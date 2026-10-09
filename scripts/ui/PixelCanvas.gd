# ==========================================
# FILE: PixelCanvas.gd
# DESCRIPTION: A tiny software rasteriser for pixel art. It mirrors the CanvasItem draw_* calls used by the
#              icon/portrait painters, so the same drawing code can render into a low-res Image that is then
#              scaled up with nearest-neighbour filtering. Includes a 3x5 bitmap font and auto-outlining.
# VERSION: v0.100
# ==========================================
class_name PixelCanvas
extends RefCounted

# 3x5 bitmap font. Each glyph is five rows of three characters ('#' = ink).
const FONT := {
	"0": ["###", "#.#", "#.#", "#.#", "###"], "1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["###", "..#", "###", "#..", "###"], "3": ["###", "..#", ".##", "..#", "###"],
	"4": ["#.#", "#.#", "###", "..#", "..#"], "5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"], "7": ["###", "..#", "..#", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"], "9": ["###", "#.#", "###", "..#", "###"],
	"+": ["...", ".#.", "###", ".#.", "..."], "-": ["...", "...", "###", "...", "..."],
	"x": ["...", "#.#", ".#.", "#.#", "..."], "$": [".##", "##.", ".#.", ".##", "##."],
	"?": ["##.", "..#", ".#.", "...", ".#."], "!": [".#.", ".#.", ".#.", "...", ".#."],
	"A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
	"C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
	"E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
	"G": [".##", "#..", "#.#", "#.#", ".##"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
	"I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", ".#."],
	"K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
	"M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
	"O": [".#.", "#.#", "#.#", "#.#", ".#."], "P": ["##.", "#.#", "##.", "#..", "#.."],
	"Q": [".#.", "#.#", "#.#", "##.", ".##"], "R": ["##.", "#.#", "##.", "#.#", "#.#"],
	"S": [".##", "#..", ".#.", "..#", "##."], "T": ["###", ".#.", ".#.", ".#.", ".#."],
	"U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
	"W": ["#.#", "#.#", "###", "###", "#.#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
	"Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
	" ": ["...", "...", "...", "...", "..."],
}

var img: Image
var width: int
var height: int
var _xf := Transform2D.IDENTITY

func _init(w: int, h: int) -> void:
	width = w
	height = h
	img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

# ---------- Core plotting ----------

func plot(x: int, y: int, col: Color) -> void:
	if x < 0 or y < 0 or x >= width or y >= height or col.a <= 0.0:
		return
	if col.a >= 1.0:
		img.set_pixel(x, y, col)
	else:
		var under := img.get_pixel(x, y)
		img.set_pixel(x, y, under.blend(col) if under.a > 0.0 else col)

func get_px(x: int, y: int) -> Color:
	if x < 0 or y < 0 or x >= width or y >= height:
		return Color(0, 0, 0, 0)
	return img.get_pixel(x, y)

func _bounds(points: PackedVector2Array, pad: float) -> Rect2i:
	var r := Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	r = r.grow(pad)
	var x0 := clampi(int(floor(r.position.x)), 0, width)
	var y0 := clampi(int(floor(r.position.y)), 0, height)
	var x1 := clampi(int(ceil(r.end.x)), 0, width)
	var y1 := clampi(int(ceil(r.end.y)), 0, height)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)

func _tx(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(_xf * p)
	return out

# ---------- CanvasItem-compatible API (subset) ----------

func draw_set_transform(pos: Vector2, rot: float = 0.0, scl: Vector2 = Vector2.ONE) -> void:
	_xf = Transform2D(rot, scl, 0.0, pos)

func draw_set_transform_matrix(m: Transform2D) -> void:
	_xf = m

func draw_colored_polygon(points: PackedVector2Array, col: Color, _uvs = null, _tex = null) -> void:
	if points.size() < 3:
		return
	var pts := _tx(points)
	var b := _bounds(pts, 0.0)
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				plot(x, y, col)

func draw_rect(rect: Rect2, col: Color, filled: bool = true, w: float = -1.0, _aa: bool = false) -> void:
	var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	if filled:
		draw_colored_polygon(pts, col)
	else:
		pts.append(rect.position)
		draw_polyline(pts, col, maxf(w, 1.0))

func draw_circle(center: Vector2, radius: float, col: Color, _filled: bool = true, _w: float = -1.0, _aa: bool = false) -> void:
	var c := _xf * center
	var r := radius * _xf.get_scale().x
	var b := _bounds(PackedVector2Array([c]), r + 1.0)
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				plot(x, y, col)

func draw_line(a: Vector2, b: Vector2, col: Color, w: float = 1.0, _aa: bool = false) -> void:
	var pa := _xf * a
	var pb := _xf * b
	var half := maxf(0.5, w * _xf.get_scale().x * 0.5)
	var box := _bounds(PackedVector2Array([pa, pb]), half + 1.0)
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var p := Vector2(x + 0.5, y + 0.5)
			if Geometry2D.get_closest_point_to_segment(p, pa, pb).distance_to(p) <= half:
				plot(x, y, col)

func draw_polyline(points: PackedVector2Array, col: Color, w: float = 1.0, _aa: bool = false) -> void:
	for i in points.size() - 1:
		draw_line(points[i], points[i + 1], col, w)

func draw_dashed_line(a: Vector2, b: Vector2, col: Color, w: float = 1.0, _dash: float = 2.0, _aligned: bool = true, _aa: bool = false) -> void:
	draw_line(a, b, col, w)

func draw_arc(center: Vector2, radius: float, a0: float, a1: float, _segments: int, col: Color, w: float = 1.0, _aa: bool = false) -> void:
	var pts := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / steps)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts, col, w)

# Text calls from UIKit.draw_text_centered land here and use the bitmap font instead.
func draw_string(_font, pos: Vector2, text: String, _align = 0, _w = -1, font_size: int = 16, col: Color = Color.WHITE, _j = 0, _d = 0, _o = 0) -> void:
	var px := maxi(1, int(round(font_size / 8.0)))
	var size := text_size(text, px)
	# pos is a baseline from draw_text_centered; recover the centre it was aiming for.
	var p := _xf * pos
	var top_left := Vector2(p.x, p.y - size.y)
	draw_text(text, Vector2i(int(round(top_left.x)), int(round(top_left.y))), px, col)

func draw_string_outline(_font, _pos: Vector2, _text: String, _align = 0, _w = -1, _font_size: int = 16, _size: int = 1, _col: Color = Color.BLACK, _j = 0, _d = 0, _o = 0) -> void:
	pass  # outlines come from outline()

# ---------- Pixel helpers ----------

static func text_size(text: String, px: int = 1) -> Vector2i:
	return Vector2i(maxi(0, text.length() * 4 - 1) * px, 5 * px)

# draw_text
# DESCRIPTION: Bitmap text at an integer pixel position and scale.
func draw_text(text: String, pos: Vector2i, px: int, col: Color) -> void:
	var x := pos.x
	for ch in text.to_upper():
		var g: Array = FONT.get(ch, FONT["?"])
		for row in 5:
			var line: String = g[row]
			for colx in 3:
				if line[colx] == "#":
					for dy in px:
						for dx in px:
							plot(x + colx * px + dx, pos.y + row * px + dy, col)
		x += 4 * px

func draw_text_centered(text: String, center: Vector2, px: int, col: Color) -> void:
	var s := text_size(text, px)
	draw_text(text, Vector2i(int(round(center.x - s.x / 2.0)), int(round(center.y - s.y / 2.0))), px, col)

# outline
# DESCRIPTION: Adds a 1px outline around every opaque pixel (classic sprite look).
func outline(col: Color, diagonal: bool = false) -> void:
	var src := img.duplicate()
	for y in height:
		for x in width:
			if src.get_pixel(x, y).a > 0.0:
				continue
			var hit := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < width and q.y < height and src.get_pixel(q.x, q.y).a > 0.0:
					hit = true
			if diagonal and not hit:
				for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
					var q: Vector2i = Vector2i(x, y) + d
					if q.x >= 0 and q.y >= 0 and q.x < width and q.y < height and src.get_pixel(q.x, q.y).a > 0.0:
						hit = true
			if hit:
				img.set_pixel(x, y, col)

func texture() -> ImageTexture:
	return ImageTexture.create_from_image(img)
