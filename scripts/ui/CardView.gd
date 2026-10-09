# ==========================================
# FILE: CardView.gd
# DESCRIPTION: A card on screen, drawn from its PixelCard sprite. Handles hover lift, playable glow, flip and smooth
#              motion toward a target (used by the battle table so cards glide between piles).
# VERSION: v0.100
# ==========================================
class_name CardView
extends Control

signal clicked(view: CardView)

const CARD_SIZE := Vector2(130, 190)

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

func _init(p_data: CardData = null, p_face_up: bool = true) -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	# Hard pixel drop shadow.
	draw_rect(Rect2(r.position + Vector2(5, 5), r.size), Color(0, 0, 0, 0.35))
	if playable or selected:
		var pulse := 0.5 + 0.5 * sin(_glow_t * 4.0)
		var glow := UIKit.GOLD if playable else Color(0.4, 0.85, 1.0)
		draw_rect(r.grow(10), Color(glow, 0.12 + 0.18 * pulse))
		draw_rect(r.grow(5), Color(glow, 0.8 + 0.2 * pulse), false, 5.0)
	draw_texture_rect(PixelCard.texture_for(data, face_up and data != null), r, false)
	draw_set_transform_matrix(Transform2D.IDENTITY)
