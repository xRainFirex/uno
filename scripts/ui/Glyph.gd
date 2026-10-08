# ==========================================
# FILE: Glyph.gd
# DESCRIPTION: Small vector icon set (hearts, coins, swords, skulls...) drawn in code so no image assets are needed.
#              Use as a Control, or call Glyph.paint() from any _draw().
# VERSION: v0.100
# ==========================================
class_name Glyph
extends Control

var icon := "star":
	set(v):
		icon = v
		queue_redraw()
var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()

func _init(p_icon: String = "star", p_color: Color = Color.WHITE, p_size: float = 32.0) -> void:
	icon = p_icon
	color = p_color
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	Glyph.paint(self, icon, size / 2.0, minf(size.x, size.y) / 2.0, color)

# paint
# DESCRIPTION: Draws `icon` centred at `c` with radius `r` onto any CanvasItem.
static func paint(ci: CanvasItem, icon_name: String, c: Vector2, r: float, col: Color) -> void:
	var dark := Color(0, 0, 0, 0.55)
	if icon_name.begins_with("text:"):
		var txt := icon_name.substr(5)
		var fs := int(r * (1.1 if txt.length() <= 2 else 0.8))
		UIKit.draw_text_centered(ci, UIKit.font_bold(), txt, c, fs, col, dark, maxi(2, int(r * 0.12)))
		return
	match icon_name:
		"heart":
			ci.draw_circle(c + Vector2(-r * 0.36, -r * 0.2), r * 0.44, col)
			ci.draw_circle(c + Vector2(r * 0.36, -r * 0.2), r * 0.44, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.78, -r * 0.05), c + Vector2(r * 0.78, -r * 0.05), c + Vector2(0, r * 0.8)]), col)
		"coin":
			ci.draw_circle(c, r * 0.85, col.darkened(0.25))
			ci.draw_circle(c + Vector2(0, -r * 0.06), r * 0.8, col)
			ci.draw_arc(c + Vector2(0, -r * 0.06), r * 0.58, 0, TAU, 32, col.darkened(0.25), maxf(1.5, r * 0.09), true)
			UIKit.draw_text_centered(ci, UIKit.font_bold(), "$", c + Vector2(0, -r * 0.06), int(r * 0.95), col.darkened(0.45))
		"sword":
			for s in [-1.0, 1.0]:
				var a := c + Vector2(-0.7 * s, -0.7) * r
				var b := c + Vector2(0.55 * s, 0.55) * r
				ci.draw_line(a, b, col, r * 0.2)
				var g := c + Vector2(0.32 * s, 0.32) * r
				var perp := Vector2(1 * s, -1).normalized() * r * 0.32
				ci.draw_line(g - perp, g + perp, col, r * 0.16)
		"skull":
			ci.draw_circle(c + Vector2(0, -r * 0.12), r * 0.68, col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.38, r * 0.25), Vector2(r * 0.76, r * 0.5)), col)
			ci.draw_circle(c + Vector2(-r * 0.27, -r * 0.1), r * 0.19, dark)
			ci.draw_circle(c + Vector2(r * 0.27, -r * 0.1), r * 0.19, dark)
			for i in 3:
				var x := -r * 0.22 + i * r * 0.22
				ci.draw_line(c + Vector2(x, r * 0.45), c + Vector2(x, r * 0.75), dark, r * 0.07)
		"crown":
			var pts := PackedVector2Array([
				c + Vector2(-0.85, 0.55) * r, c + Vector2(-0.85, -0.45) * r, c + Vector2(-0.42, 0.02) * r,
				c + Vector2(0, -0.7) * r, c + Vector2(0.42, 0.02) * r, c + Vector2(0.85, -0.45) * r, c + Vector2(0.85, 0.55) * r,
			])
			ci.draw_colored_polygon(pts, col)
			for p in [Vector2(-0.85, -0.5), Vector2(0, -0.75), Vector2(0.85, -0.5)]:
				ci.draw_circle(c + p * r, r * 0.13, col)
			ci.draw_line(c + Vector2(-0.85, 0.36) * r, c + Vector2(0.85, 0.36) * r, dark, r * 0.1)
		"flame":
			_flame(ci, c, r, col)
			_flame(ci, c + Vector2(0, r * 0.25), r * 0.55, col.lightened(0.5))
		"question":
			ci.draw_circle(c, r * 0.85, col)
			UIKit.draw_text_centered(ci, UIKit.font_bold(), "?", c, int(r * 1.3), dark.darkened(0.5))
		"chest":
			ci.draw_rect(Rect2(c + Vector2(-0.8, -0.2) * r, Vector2(1.6, 0.85) * r), col)
			var lid := UIKit.ellipse_points(c + Vector2(0, -0.2) * r, Vector2(0.8, 0.5) * r, 0.0, 16, PI, TAU)
			ci.draw_colored_polygon(lid, col.lightened(0.15))
			ci.draw_line(c + Vector2(-0.8, -0.2) * r, c + Vector2(0.8, -0.2) * r, dark, r * 0.1)
			ci.draw_rect(Rect2(c + Vector2(-0.14, -0.3) * r, Vector2(0.28, 0.36) * r), dark)
		"bag":
			ci.draw_circle(c + Vector2(0, r * 0.2), r * 0.66, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.3, -0.35) * r, c + Vector2(0.3, -0.35) * r, c + Vector2(0.48, -0.8) * r, c + Vector2(-0.48, -0.8) * r]), col)
			ci.draw_line(c + Vector2(-0.34, -0.38) * r, c + Vector2(0.34, -0.38) * r, dark, r * 0.12)
			UIKit.draw_text_centered(ci, UIKit.font_bold(), "$", c + Vector2(0, r * 0.22), int(r * 0.8), dark.darkened(0.4))
		"cards":
			var size := Vector2(0.95, 1.35) * r
			ci.draw_set_transform(c + Vector2(-0.18, 0.05) * r, -0.25, Vector2.ONE)
			ci.draw_rect(Rect2(-size / 2.0, size), col.darkened(0.3))
			ci.draw_set_transform(c + Vector2(0.18, -0.05) * r, 0.18, Vector2.ONE)
			ci.draw_rect(Rect2(-size / 2.0, size), col)
			ci.draw_rect(Rect2(-size / 2.0 + Vector2(r * 0.12, r * 0.12), size - Vector2(r * 0.24, r * 0.24)), dark, false, maxf(1.0, r * 0.06))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"shield":
			var pts := PackedVector2Array([
				c + Vector2(-0.75, -0.7) * r, c + Vector2(0.75, -0.7) * r, c + Vector2(0.7, 0.1) * r,
				c + Vector2(0, 0.85) * r, c + Vector2(-0.7, 0.1) * r,
			])
			ci.draw_colored_polygon(pts, col)
			ci.draw_line(c + Vector2(0, -0.7) * r, c + Vector2(0, 0.85) * r, dark, r * 0.08)
		"eye":
			var outer := UIKit.ellipse_points(c, Vector2(0.9, 0.5) * r, 0.0, 32)
			ci.draw_colored_polygon(outer, col)
			ci.draw_circle(c, r * 0.36, dark.darkened(0.6))
			ci.draw_circle(c + Vector2(-r * 0.1, -r * 0.1), r * 0.1, Color(1, 1, 1, 0.9))
		"fang":
			for s in [-1.0, 1.0]:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.62 * s - 0.28, -0.6) * r, c + Vector2(0.62 * s + 0.28, -0.6) * r, c + Vector2(0.45 * s, 0.75) * r]), col)
			ci.draw_rect(Rect2(c + Vector2(-0.95, -0.85) * r, Vector2(1.9, 0.3) * r), col.darkened(0.3))
		"diamond":
			var cols := [UIKit.card_color(0), UIKit.card_color(1), UIKit.card_color(2), UIKit.card_color(3)]
			var pts := [c + Vector2(0, -0.9) * r, c + Vector2(0.75, 0) * r, c + Vector2(0, 0.9) * r, c + Vector2(-0.75, 0) * r]
			for i in 4:
				ci.draw_colored_polygon(PackedVector2Array([c, pts[i], pts[(i + 1) % 4]]), cols[i])
		"reverse":
			draw_arrow(ci, c + Vector2(-0.15, -0.2) * r, c + Vector2(0.7, -0.2) * r, col, r * 0.2)
			draw_arrow(ci, c + Vector2(0.15, 0.3) * r, c + Vector2(-0.7, 0.3) * r, col, r * 0.2)
		"search":
			ci.draw_arc(c + Vector2(-0.15, -0.15) * r, r * 0.5, 0, TAU, 32, col, r * 0.18, true)
			ci.draw_line(c + Vector2(0.22, 0.22) * r, c + Vector2(0.75, 0.75) * r, col, r * 0.24)
		"map":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8, -0.6) * r, c + Vector2(-0.25, -0.75) * r, c + Vector2(0.25, -0.6) * r, c + Vector2(0.8, -0.75) * r, c + Vector2(0.8, 0.6) * r, c + Vector2(0.25, 0.75) * r, c + Vector2(-0.25, 0.6) * r, c + Vector2(-0.8, 0.75) * r]), col)
		"mask":
			var face := UIKit.ellipse_points(c, Vector2(0.9, 0.62) * r, 0.0, 32)
			ci.draw_colored_polygon(face, col)
			ci.draw_colored_polygon(UIKit.ellipse_points(c, Vector2(0.9, 0.62) * r, 0.0, 16, -PI / 2.0, PI / 2.0), col.darkened(0.35))
			for sgn in [-1.0, 1.0]:
				ci.draw_colored_polygon(UIKit.ellipse_points(c + Vector2(sgn * 0.38, -0.08) * r, Vector2(0.22, 0.13) * r, sgn * 0.25, 16), dark.darkened(0.6))
		"dice":
			ci.draw_rect(Rect2(c - Vector2(0.75, 0.75) * r, Vector2(1.5, 1.5) * r), col)
			for p in [Vector2(-0.4, -0.4), Vector2(0.4, -0.4), Vector2(0, 0), Vector2(-0.4, 0.4), Vector2(0.4, 0.4)]:
				ci.draw_circle(c + p * r, r * 0.14, dark.darkened(0.6))
		"snowflake":
			for i in 3:
				var d := Vector2.UP.rotated(i * PI / 3.0) * r * 0.85
				ci.draw_line(c - d, c + d, col, r * 0.14)
				for sgn in [-1.0, 1.0]:
					var base: Vector2 = c + d * 0.55 * sgn
					ci.draw_line(base, base + (d * sgn * 0.45).rotated(0.8), col, r * 0.1)
					ci.draw_line(base, base + (d * sgn * 0.45).rotated(-0.8), col, r * 0.1)
		"gift":
			ci.draw_rect(Rect2(c + Vector2(-0.65, -0.1) * r, Vector2(1.3, 0.85) * r), col)
			ci.draw_rect(Rect2(c + Vector2(-0.78, -0.42) * r, Vector2(1.56, 0.34) * r), col.lightened(0.15))
			ci.draw_rect(Rect2(c + Vector2(-0.1, -0.42) * r, Vector2(0.2, 1.17) * r), dark)
			for sgn in [-1.0, 1.0]:
				ci.draw_colored_polygon(UIKit.ellipse_points(c + Vector2(sgn * 0.25, -0.6) * r, Vector2(0.24, 0.15) * r, sgn * 0.5, 16), col)
		"clock":
			ci.draw_arc(c, r * 0.78, 0, TAU, 32, col, r * 0.14, true)
			ci.draw_line(c, c + Vector2(0, -0.5) * r, col, r * 0.12)
			ci.draw_line(c, c + Vector2(0.38, 0.12) * r, col, r * 0.12)
			ci.draw_circle(c, r * 0.1, col)
		"mirror":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.12, -0.7) * r, c + Vector2(-0.12, 0.7) * r, c + Vector2(-0.85, 0) * r]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.12, -0.7) * r, c + Vector2(0.12, 0.7) * r, c + Vector2(0.85, 0) * r]), col.darkened(0.3))
		"joker":
			var tips := [Vector2(-0.8, -0.55), Vector2(0, -0.85), Vector2(0.8, -0.55)]
			for t in tips:
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.45, 0.35) * r, c + Vector2(0.45, 0.35) * r, c + t * r]), col)
				ci.draw_circle(c + t * r, r * 0.14, col.lightened(0.3))
			ci.draw_rect(Rect2(c + Vector2(-0.6, 0.3) * r, Vector2(1.2, 0.3) * r), col.darkened(0.3))
		_:
			_star(ci, c, r, col)

static func _flame(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0 * TAU
		var x := sin(t) * 0.62
		var y := -cos(t) * 0.55 + 0.25
		if y < 0.0:
			y *= 1.0 + (1.0 - absf(x) / 0.62) * 0.9
		pts.append(c + Vector2(x, y) * r)
	ci.draw_colored_polygon(pts, col)

static func _star(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r * (0.9 if i % 2 == 0 else 0.4)
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	ci.draw_colored_polygon(pts, col)

# draw_arrow
# DESCRIPTION: Thick arrow with a triangular head, shared with the card renderer.
static func draw_arrow(ci: CanvasItem, from: Vector2, to: Vector2, col: Color, width: float) -> void:
	var dir := (to - from).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var head := width * 2.0
	ci.draw_line(from, to - dir * head * 0.8, col, width)
	ci.draw_colored_polygon(PackedVector2Array([to, to - dir * head + perp * head * 0.75, to - dir * head - perp * head * 0.75]), col)
