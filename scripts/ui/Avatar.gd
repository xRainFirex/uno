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

func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	var col: Color = enemy.get("color", Color.GRAY)
	var kind: String = enemy.get("kind", "battle")
	var ring := UIKit.GOLD if kind == "boss" else (UIKit.DANGER if kind == "elite" else Color(1, 1, 1, 0.5))
	draw_circle(c, r, ring)
	draw_circle(c, r * 0.92, col.darkened(0.55))
	# Shoulders
	draw_colored_polygon(UIKit.ellipse_points(c + Vector2(0, r * 0.95), Vector2(r * 0.72, r * 0.5), 0.0, 24, PI, TAU), col.darkened(0.15))
	# Head
	draw_circle(c + Vector2(0, -r * 0.05), r * 0.44, col)
	# Mask band and eyes
	var band := Rect2(c + Vector2(-r * 0.44, -r * 0.16), Vector2(r * 0.88, r * 0.2))
	draw_rect(band, Color(0.05, 0.05, 0.08, 0.85))
	draw_circle(c + Vector2(-r * 0.17, -r * 0.06), r * 0.06, Color.WHITE)
	draw_circle(c + Vector2(r * 0.17, -r * 0.06), r * 0.06, Color.WHITE)
	# Hat: top hat for bosses, card-suit crest for elites
	if kind == "boss":
		Glyph.paint(self, "crown", c + Vector2(0, -r * 0.6), r * 0.32, UIKit.GOLD)
	elif kind == "elite":
		Glyph.paint(self, "skull", c + Vector2(0, -r * 0.62), r * 0.2, UIKit.DANGER.lightened(0.3))
	var initial: String = String(enemy.get("name", "?")).replace("The ", "").substr(0, 1)
	draw_circle(c + Vector2(r * 0.62, r * 0.62), r * 0.26, UIKit.GOLD.darkened(0.1))
	UIKit.draw_text_centered(self, UIKit.font_bold(), initial, c + Vector2(r * 0.62, r * 0.62), int(r * 0.32), Color(0.1, 0.08, 0.04))
	if flash > 0.0:
		draw_circle(c, r, Color(1, 1, 1, flash * 0.6))
