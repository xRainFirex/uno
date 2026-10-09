# ==========================================
# FILE: UIKit.gd
# DESCRIPTION: Shared palette, fonts, theme and small widget factories so every screen looks consistent.
# VERSION: v0.100
# ==========================================
class_name UIKit
extends RefCounted

const BG := Color(0.043, 0.071, 0.094)
const PANEL := Color(0.078, 0.11, 0.15, 0.96)
const PANEL_LIGHT := Color(0.115, 0.16, 0.215, 1.0)
const BORDER := Color(0.2, 0.27, 0.36)
const TEXT := Color(0.93, 0.95, 0.97)
const TEXT_MUTED := Color(0.56, 0.63, 0.71)
const GOLD := Color(0.96, 0.77, 0.26)
const DANGER := Color(0.9, 0.28, 0.3)
const SUCCESS := Color(0.22, 0.77, 0.48)
# Elemental suits: Ember, Tide, Moss, Dusk (and the dark Wild body).
const CARD_COLORS := [Color(0.93, 0.36, 0.23), Color(0.2, 0.6, 0.86), Color(0.42, 0.75, 0.29), Color(0.6, 0.38, 0.88), Color(0.17, 0.13, 0.26)]

static var _bold: FontVariation
static var _heavy_italic: FontVariation
static var _regular: FontVariation

static func card_color(i: int) -> Color:
	return CARD_COLORS[clampi(i, 0, 4)]

const FONT_BODY := preload("res://assets/fonts/Jersey10-Regular.ttf")
const FONT_TITLE := preload("res://assets/fonts/Silkscreen-Bold.ttf")
# Jersey 10 runs small for its point size, so body text sizes are scaled up to match the layout.
const BODY_SCALE := 1.3

static func fs(size: int) -> int:
	return int(round(size * BODY_SCALE))

static func _pixel_font(base: Font, embolden: float) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	f.variation_embolden = embolden
	return f

static func font_regular() -> Font:
	if _regular == null:
		_regular = _pixel_font(FONT_BODY, 0.0)
	return _regular

static func font_bold() -> Font:
	if _bold == null:
		_bold = _pixel_font(FONT_BODY, 0.0)
	return _bold

# font_display
# DESCRIPTION: Chunky pixel display face for titles and big callouts.
static func font_display() -> Font:
	if _heavy_italic == null:
		_heavy_italic = _pixel_font(FONT_TITLE, 0.0)
	return _heavy_italic

static func stylebox(bg: Color, radius: int = 14, border: int = 0, border_color: Color = BORDER, shadow: int = 0) -> StyleBoxFlat:
	# Pixel look: square corners (round ones only for deliberate circles), crisp edges, hard drop shadows.
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius if radius >= 60 else 0)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	sb.anti_aliasing = radius >= 60
	if shadow > 0:
		sb.shadow_size = 1
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_offset = Vector2(1, 1) * clampf(shadow * 0.5, 3.0, 8.0)
	return sb

static func panel_style(radius: int = 18) -> StyleBoxFlat:
	var sb := stylebox(PANEL, radius, 3, BORDER, 16)
	sb.set_content_margin_all(22)
	return sb

static func _button_styles(theme: Theme, type_name: String, base: Color, border: Color) -> void:
	var states := {
		"normal": base,
		"hover": base.lightened(0.12),
		"pressed": base.darkened(0.15),
		"disabled": base.darkened(0.45),
		"focus": base,
	}
	for state in states:
		var sb := stylebox(states[state], 12, 2, border if state != "disabled" else border.darkened(0.5), 6 if state == "normal" or state == "hover" else 0)
		sb.content_margin_left = 26
		sb.content_margin_right = 26
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		if state == "focus":
			sb.draw_center = false
			sb.border_color = border.lightened(0.3)
			sb.shadow_size = 0
		theme.set_stylebox(state, type_name, sb)

# build_theme
# DESCRIPTION: Creates the global theme applied to the root of the game.
static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font_regular()
	t.default_font_size = fs(20)

	_button_styles(t, "Button", PANEL_LIGHT, BORDER)
	t.set_font("font", "Button", font_bold())
	t.set_font_size("font_size", "Button", fs(21))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", TEXT_MUTED)
	t.set_color("font_disabled_color", "Button", TEXT_MUTED.darkened(0.4))
	t.set_color("font_focus_color", "Button", TEXT)

	t.add_type("AccentButton")
	t.set_type_variation("AccentButton", "Button")
	_button_styles(t, "AccentButton", GOLD.darkened(0.1), GOLD.lightened(0.25))
	t.set_color("font_color", "AccentButton", Color(0.13, 0.1, 0.04))
	t.set_color("font_hover_color", "AccentButton", Color(0.08, 0.06, 0.02))
	t.set_color("font_pressed_color", "AccentButton", Color(0.2, 0.16, 0.06))
	t.set_color("font_focus_color", "AccentButton", Color(0.13, 0.1, 0.04))
	t.set_color("font_disabled_color", "AccentButton", Color(0.95, 0.9, 0.75, 0.75))

	t.add_type("DangerButton")
	t.set_type_variation("DangerButton", "Button")
	_button_styles(t, "DangerButton", DANGER.darkened(0.15), DANGER.lightened(0.2))

	t.add_type("GhostButton")
	t.set_type_variation("GhostButton", "Button")
	_button_styles(t, "GhostButton", Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.14))

	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())

	var tip := stylebox(Color(0.05, 0.07, 0.1, 0.97), 10, 2, GOLD.darkened(0.35), 8)
	tip.set_content_margin_all(12)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", fs(18))

	var grabber := stylebox(Color(1, 1, 1, 0.25), 6)
	var grabber_hl := stylebox(Color(1, 1, 1, 0.4), 6)
	var track := stylebox(Color(1, 1, 1, 0.05), 6)
	track.content_margin_left = 6
	track.content_margin_right = 6
	for sb_type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_type, track)
		t.set_stylebox("grabber", sb_type, grabber)
		t.set_stylebox("grabber_highlight", sb_type, grabber_hl)
		t.set_stylebox("grabber_pressed", sb_type, grabber_hl)

	t.set_font("normal_font", "RichTextLabel", font_regular())
	t.set_font("bold_font", "RichTextLabel", font_bold())
	t.set_color("default_color", "RichTextLabel", TEXT)
	return t

# label
# DESCRIPTION: Creates a label with consistent styling.
static func label(text: String, size: int = 20, color: Color = TEXT, bold: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold())
	return l

# title
# DESCRIPTION: Big display heading with an outline.
static func title(text: String, size: int = 64, color: Color = TEXT) -> Label:
	var l := label(text, size, color, false, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_font_override("font", font_display())
	# Silkscreen is drawn on an 8px grid; multiples of 8 keep its pixels even.
	l.add_theme_font_size_override("font_size", maxi(16, int(round(size / 8.0)) * 8))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("outline_size", maxi(4, size / 8))
	return l

static func button(text: String, variant: String = "", min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if variant != "":
		b.theme_type_variation = variant
	b.custom_minimum_size = min_size
	b.pressed.connect(func(): Sfx.play("click"))
	return b

static func panel(radius: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(radius))
	return p

static func vbox(sep: int = 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b

static func hbox(sep: int = 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b

# dimmer
# DESCRIPTION: Full-screen translucent backdrop for modals; blocks clicks to what's behind it.
static func dimmer(alpha: float = 0.72) -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0.01, 0.02, 0.03, alpha)
	d.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	return d

static func centered(child: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(child)
	return c

static func spacer(h: float = 0.0, v: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(h, v)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func expand_spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

# draw_text_centered
# DESCRIPTION: Draws outlined text centred on a point. Used by custom-drawn widgets.
static func draw_text_centered(ci: CanvasItem, font: Font, text: String, center: Vector2, font_size: int, fill: Color, outline: Color = Color(0, 0, 0, 0), outline_px: int = 0) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var asc := font.get_ascent(font_size)
	var desc := font.get_descent(font_size)
	var pos := center + Vector2(-w / 2.0, (asc - desc) / 2.0)
	if outline_px > 0:
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_px, outline)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fill)

static func ellipse_points(center: Vector2, radii: Vector2, tilt: float, segments: int = 48, from_angle: float = 0.0, to_angle: float = TAU) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments + 1:
		var a := lerpf(from_angle, to_angle, float(i) / segments)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(tilt))
	return pts
