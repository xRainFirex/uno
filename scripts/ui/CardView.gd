# ==========================================
# FILE: CardView.gd
# DESCRIPTION: Fully code-drawn card. Handles hover lift, playable glow, flip animation and smooth
#              motion toward a target (used by the battle table so cards glide between piles).
# VERSION: v0.100
# ==========================================
class_name CardView
extends Control

signal clicked(view: CardView)

const CARD_SIZE := Vector2(130, 190)
const OVAL_TILT := 0.49
const OUTLINE := Color(0.06, 0.06, 0.09)
const ENCHANT_COLORS := [Color.WHITE, Color(1.0, 0.8, 0.25), Color(0.8, 0.35, 1.0), Color(0.3, 0.95, 0.55)]

var data: CardData:
	set(v):
		data = v
		_refresh_tooltip()
		queue_redraw()
var face_up := true:
	set(v):
		face_up = v
		_refresh_tooltip()
		queue_redraw()
var playable := false:
	set(v):
		playable = v
		queue_redraw()
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var dimmed := false
var hovered := false
var interactive := false:
	set(v):
		interactive = v
		mouse_filter = Control.MOUSE_FILTER_STOP if v else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if v else Control.CURSOR_ARROW
		_refresh_tooltip()
var show_tooltip := true
var hover_lift := 28.0
var hover_grow := 0.07

# Free motion (battle table)
var animate_motion := false
var target_center := Vector2.ZERO
var target_rotation := 0.0
var target_scale := Vector2.ONE
var motion_speed := 11.0

var _hover_t := 0.0
var _glow_t := 0.0
var _flip := 1.0:
	set(v):
		_flip = v
		queue_redraw()
var _base := Transform2D.IDENTITY
var _sb_body: StyleBoxFlat
var _sb_inner: StyleBoxFlat
var _sb_glow: StyleBoxFlat
var _sb_ring: StyleBoxFlat

func _init(p_data: CardData = null, p_face_up: bool = true) -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sb_body = UIKit.stylebox(Color(0.985, 0.98, 0.965), 13)
	_sb_body.shadow_color = Color(0, 0, 0, 0.42)
	_sb_body.shadow_size = 9
	_sb_body.shadow_offset = Vector2(0, 5)
	_sb_inner = UIKit.stylebox(Color.RED, 9)
	_sb_glow = UIKit.stylebox(Color(0, 0, 0, 0), 17, 4, UIKit.GOLD)
	_sb_glow.draw_center = false
	_sb_glow.shadow_color = Color(UIKit.GOLD, 0.6)
	_sb_glow.shadow_size = 16
	_sb_ring = UIKit.stylebox(Color(0, 0, 0, 0), 9, 3, Color.WHITE)
	_sb_ring.draw_center = false
	data = p_data
	face_up = p_face_up

func _ready() -> void:
	mouse_entered.connect(func():
		if interactive:
			hovered = true
			Sfx.play("hover", 1.0, -8.0))
	mouse_exited.connect(func():
		if interactive:
			hovered = false)

func _gui_input(event: InputEvent) -> void:
	if interactive and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()

func _refresh_tooltip() -> void:
	if interactive and show_tooltip and face_up and data != null:
		tooltip_text = "%s\n%s" % [data.title(), data.describe()]
	else:
		tooltip_text = ""

# place_at
# DESCRIPTION: Snap to a centre point immediately (no animation).
func place_at(center: Vector2, rot: float = 0.0) -> void:
	position = center - size / 2.0
	rotation = rot
	target_center = center
	target_rotation = rot

# flip_to
# DESCRIPTION: Animated card flip.
func flip_to(up: bool, duration: float = 0.24) -> void:
	if up == face_up:
		return
	var tw := create_tween()
	tw.tween_property(self, "_flip", 0.0, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): face_up = up)
	tw.tween_property(self, "_flip", 1.0, duration / 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# shake
# DESCRIPTION: Little "nope" wiggle for invalid plays.
func shake() -> void:
	var tw := create_tween()
	var r := target_rotation if animate_motion else rotation
	for i in 4:
		tw.tween_property(self, "rotation", r + (0.07 if i % 2 == 0 else -0.07), 0.04)
	tw.tween_property(self, "rotation", r, 0.04)

func _process(delta: float) -> void:
	var target_h := 1.0 if hovered else 0.0
	if not is_equal_approx(_hover_t, target_h):
		_hover_t = move_toward(_hover_t, target_h, delta * 7.0)
		queue_redraw()
	if playable or selected:
		_glow_t += delta
		queue_redraw()
	if animate_motion:
		var k := 1.0 - exp(-motion_speed * delta)
		position = position.lerp(target_center - size / 2.0, k)
		rotation = lerp_angle(rotation, target_rotation, k)
		scale = scale.lerp(target_scale, k)
	var target_mod := Color(0.58, 0.6, 0.66) if dimmed else Color.WHITE
	if not modulate.is_equal_approx(target_mod):
		modulate = modulate.lerp(target_mod, minf(1.0, delta * 10.0))

func _draw() -> void:
	var ease_h := ease(_hover_t, -2.0)
	var sc := 1.0 + hover_grow * ease_h
	_base = Transform2D(0.0, Vector2(sc * maxf(_flip, 0.02), sc), 0.0, size / 2.0 + Vector2(0, -hover_lift * ease_h))
	draw_set_transform_matrix(_base)
	var r := Rect2(-CARD_SIZE / 2.0, CARD_SIZE)
	if playable or selected:
		var pulse := 0.5 + 0.5 * sin(_glow_t * 4.0)
		_sb_glow.border_color = UIKit.GOLD if playable else Color(0.4, 0.85, 1.0)
		_sb_glow.shadow_color = Color(_sb_glow.border_color, 0.35 + 0.35 * pulse)
		draw_style_box(_sb_glow, r.grow(5))
	draw_style_box(_sb_body, r)
	if face_up and data != null:
		_draw_face(r)
	else:
		_draw_back(r)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _xf(local: Transform2D) -> void:
	draw_set_transform_matrix(_base * local)

func _draw_back(r: Rect2) -> void:
	var inner := r.grow(-7)
	_sb_inner.bg_color = Color(0.09, 0.09, 0.13)
	draw_style_box(_sb_inner, inner)
	_sb_ring.border_color = Color(UIKit.GOLD, 0.45)
	_sb_ring.set_border_width_all(2)
	draw_style_box(_sb_ring, inner.grow(-6))
	var oval := UIKit.ellipse_points(Vector2.ZERO, Vector2(44, 70), OVAL_TILT)
	draw_colored_polygon(oval, UIKit.card_color(0))
	draw_polyline(oval, Color(1, 1, 1, 0.9), 3.0, true)
	_xf(Transform2D(-0.35, Vector2.ZERO))
	UIKit.draw_text_centered(self, UIKit.font_display(), "DOS", Vector2.ZERO, 46, UIKit.GOLD, OUTLINE, 10)
	draw_set_transform_matrix(_base)

func _draw_face(r: Rect2) -> void:
	var col := UIKit.card_color(data.card_color)
	var inner := r.grow(-7)
	if data.is_wild() and data.chosen_color >= 0:
		_sb_inner.bg_color = UIKit.card_color(data.chosen_color).darkened(0.25)
	else:
		_sb_inner.bg_color = col
	draw_style_box(_sb_inner, inner)
	# Soft sheen across the upper half
	var sheen := PackedVector2Array([inner.position + Vector2(4, 4), inner.position + Vector2(inner.size.x - 4, 4), inner.position + Vector2(inner.size.x - 4, inner.size.y * 0.28), inner.position + Vector2(4, inner.size.y * 0.55)])
	draw_colored_polygon(sheen, Color(1, 1, 1, 0.07))

	var radii := Vector2(46, 72)
	if data.is_wild():
		var quad_cols := [UIKit.card_color(0), UIKit.card_color(1), UIKit.card_color(3), UIKit.card_color(2)]
		for q in 4:
			var pts := UIKit.ellipse_points(Vector2.ZERO, radii, OVAL_TILT, 12, q * PI / 2.0, (q + 1) * PI / 2.0)
			pts.insert(0, Vector2.ZERO)
			draw_colored_polygon(pts, quad_cols[q])
		draw_polyline(UIKit.ellipse_points(Vector2.ZERO, radii, OVAL_TILT), Color.WHITE, 3.0, true)
	else:
		draw_colored_polygon(UIKit.ellipse_points(Vector2.ZERO, radii, OVAL_TILT), Color(1, 1, 1, 0.97))

	var fill := Color.WHITE if data.is_wild() else col
	_draw_symbol(Vector2.ZERO, fill, true)

	var corner := inner.position + Vector2(18, 22)
	_xf(Transform2D(0.0, corner))
	_draw_symbol(Vector2.ZERO, Color.WHITE, false)
	_xf(Transform2D(PI, -corner))
	_draw_symbol(Vector2.ZERO, Color.WHITE, false)
	draw_set_transform_matrix(_base)

	if data.enchant != CardData.Enchant.NONE:
		var ec: Color = ENCHANT_COLORS[data.enchant]
		_sb_ring.border_color = ec
		_sb_ring.set_border_width_all(3)
		draw_style_box(_sb_ring, inner.grow(-2))
		var bc := Vector2(inner.end.x - 18, inner.position.y + 18)
		draw_circle(bc, 13, OUTLINE)
		draw_circle(bc, 11, ec)
		match data.enchant:
			CardData.Enchant.GILDED:
				UIKit.draw_text_centered(self, UIKit.font_bold(), "$", bc, 16, OUTLINE)
			CardData.Enchant.BARBED:
				UIKit.draw_text_centered(self, UIKit.font_bold(), "+1", bc, 12, OUTLINE)
			CardData.Enchant.HEALING:
				draw_rect(Rect2(bc - Vector2(2, 6.5), Vector2(4, 13)), OUTLINE)
				draw_rect(Rect2(bc - Vector2(6.5, 2), Vector2(13, 4)), OUTLINE)

# _draw_symbol
# DESCRIPTION: Draws the card's symbol, either large in the centre oval or small as a corner index.
func _draw_symbol(c: Vector2, fill: Color, big: bool) -> void:
	var outline_px := 10 if big else 5
	var font := UIKit.font_display()
	match data.type:
		CardData.Type.NUMBER:
			var fs := 88 if big else 34
			UIKit.draw_text_centered(self, font, str(data.value), c, fs, fill, OUTLINE, outline_px)
			if (data.value == 6 or data.value == 9) and big:
				draw_line(c + Vector2(-16, 40), c + Vector2(14, 40), OUTLINE, 9)
				draw_line(c + Vector2(-14, 40), c + Vector2(12, 40), fill, 5)
		CardData.Type.SKIP:
			var rad := 30.0 if big else 10.5
			var w := rad * 0.3
			draw_arc(c, rad, 0, TAU, 40, OUTLINE, w + (6 if big else 3), true)
			draw_line(c + Vector2(-rad, rad) * 0.7, c + Vector2(rad, -rad) * 0.7, OUTLINE, w + (6 if big else 3))
			draw_arc(c, rad, 0, TAU, 40, fill, w, true)
			draw_line(c + Vector2(-rad, rad) * 0.7, c + Vector2(rad, -rad) * 0.7, fill, w)
		CardData.Type.REVERSE:
			var u := 34.0 if big else 12.0
			var d := Vector2(1, -1).normalized()
			var p := Vector2(1, 1).normalized()
			for pass_i in 2:
				var col := OUTLINE if pass_i == 0 else fill
				var w := u * 0.2 + ((5.0 if big else 2.5) if pass_i == 0 else 0.0)
				Glyph.draw_arrow(self, c - p * u * 0.42 - d * u * 0.75, c - p * u * 0.42 + d * u * 0.85, col, w)
				Glyph.draw_arrow(self, c + p * u * 0.42 + d * u * 0.75, c + p * u * 0.42 - d * u * 0.85, col, w)
		CardData.Type.DRAW_TWO:
			UIKit.draw_text_centered(self, font, "+2", c, 70 if big else 28, fill, OUTLINE, outline_px)
		CardData.Type.WILD_DRAW_FOUR:
			UIKit.draw_text_centered(self, font, "+4", c, 70 if big else 28, Color.WHITE, OUTLINE, outline_px)
		CardData.Type.WILD:
			if not big:
				var mini := Vector2(10, 15)
				var quad_cols := [UIKit.card_color(0), UIKit.card_color(1), UIKit.card_color(3), UIKit.card_color(2)]
				draw_colored_polygon(UIKit.ellipse_points(c, mini + Vector2(2.5, 2.5), OVAL_TILT, 24), OUTLINE)
				for q in 4:
					var pts := UIKit.ellipse_points(c, mini, OVAL_TILT, 8, q * PI / 2.0, (q + 1) * PI / 2.0)
					pts.insert(0, c)
					draw_colored_polygon(pts, quad_cols[q])
		CardData.Type.DISCARD_ALL:
			if big:
				var card_sz := Vector2(30, 44)
				for i in 3:
					var t := Transform2D((i - 1) * 0.3, c + Vector2((i - 1) * 14, -16 + absf(i - 1) * 4))
					_xf(t)
					draw_rect(Rect2(-card_sz / 2.0 - Vector2(3, 3), card_sz + Vector2(6, 6)), OUTLINE)
					draw_rect(Rect2(-card_sz / 2.0, card_sz), fill)
				draw_set_transform_matrix(_base)
				UIKit.draw_text_centered(self, font, "ALL", c + Vector2(0, 36), 28, fill, OUTLINE, 7)
			else:
				UIKit.draw_text_centered(self, UIKit.font_bold(), "ALL", c, 17, fill, OUTLINE, 4)
		CardData.Type.WILD_SWAP:
			var u := 30.0 if big else 11.0
			for pass_i in 2:
				var col := OUTLINE if pass_i == 0 else Color.WHITE
				var w := u * 0.26 + (6.0 if pass_i == 0 and big else (3.0 if pass_i == 0 else 0.0))
				Glyph.draw_arrow(self, c + Vector2(-u * 0.4, u * 0.9), c + Vector2(-u * 0.4, -u * 0.9), col, w)
				Glyph.draw_arrow(self, c + Vector2(u * 0.4, -u * 0.9), c + Vector2(u * 0.4, u * 0.9), col, w)
