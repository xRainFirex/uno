# ==========================================
# FILE: Avatar.gd
# DESCRIPTION: Procedural opponent portrait: a coloured medallion with a stylised masked face and an initial.
# VERSION: v0.100
# ==========================================
class_name Avatar
extends Control

var enemy: Dictionary = {}
var flash := 0.0:
	set(v):
		flash = v
		queue_redraw()

func _init(p_enemy: Dictionary = {}, px: float = 120.0) -> void:
	enemy = p_enemy
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# hit
# DESCRIPTION: Brief white flash when the opponent is hurt or caught.
func hit() -> void:
	flash = 1.0
	create_tween().tween_property(self, "flash", 0.0, 0.35)

const PX := 28
static var _cache := {}

func _draw() -> void:
	draw_texture_rect(portrait(enemy), Rect2(Vector2.ZERO, size), false)
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash * 0.6))

# portrait
# DESCRIPTION: A 28x28 pixel-art bust: framed (red for elites, gold for bosses), masked face and an initial tag.
static func portrait(e: Dictionary) -> ImageTexture:
	var key := "%s|%s" % [e.get("name", "?"), e.get("kind", "battle")]
	if _cache.has(key):
		return _cache[key]
	var pc := PixelCanvas.new(PX, PX)
	var col: Color = e.get("color", Color.GRAY)
	var kind: String = e.get("kind", "battle")
	var frame := UIKit.GOLD if kind == "boss" else (UIKit.DANGER if kind == "elite" else Color(0.55, 0.6, 0.7))
	var ink := PixelCard.INK
	pc.draw_rect(Rect2(0, 0, PX, PX), ink)
	pc.draw_rect(Rect2(1, 1, PX - 2, PX - 2), frame)
	pc.draw_rect(Rect2(3, 3, PX - 6, PX - 6), col.darkened(0.6))
	# Background dither
	for y in range(3, PX - 3):
		for x in range(3, PX - 3):
			if (x + y) % 4 == 0:
				pc.plot(x, y, col.darkened(0.5))
	# Shoulders and head
	pc.draw_colored_polygon(UIKit.ellipse_points(Vector2(14, 27), Vector2(9, 7), 0.0, 20, PI, TAU), col.darkened(0.15))
	pc.draw_circle(Vector2(14, 13.5), 6.5, col)
	pc.draw_rect(Rect2(10, 11, 1, 6), col.lightened(0.25))
	# Mask band and eyes
	pc.draw_rect(Rect2(7, 11, 14, 3), Color(0.05, 0.04, 0.08))
	pc.plot(11, 12, Color.WHITE)
	pc.plot(16, 12, Color.WHITE)
	# Hat
	if kind == "boss":
		Glyph.paint_shapes(pc, "crown", Vector2(14, 5.5), 4.5, UIKit.GOLD)
	elif kind == "elite":
		Glyph.paint_shapes(pc, "skull", Vector2(14, 5.5), 3.5, UIKit.DANGER.lightened(0.3))
	# Initial tag
	var initial: String = String(e.get("name", "?")).replace("The ", "").substr(0, 1)
	pc.draw_rect(Rect2(PX - 9, PX - 9, 8, 8), ink)
	pc.draw_rect(Rect2(PX - 8, PX - 8, 6, 6), UIKit.GOLD)
	pc.draw_text(initial, Vector2i(PX - 6, PX - 7), 1, ink)
	_cache[key] = pc.texture()
	return _cache[key]
