# ==========================================
# FILE: CharmIcon.gd
# DESCRIPTION: Hexagonal badge for a charm, with its name and effect as a tooltip.
# VERSION: v0.100
# ==========================================
class_name CharmIcon
extends Control

signal clicked(charm_id: String)

var charm_id := ""
var _hover := false

func _init(id: String = "", px: float = 46.0) -> void:
	charm_id = id
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var def := Charms.get_def(id)
	tooltip_text = "%s\n%s" % [def.name, def.desc]

func _ready() -> void:
	mouse_entered.connect(func():
		_hover = true
		queue_redraw())
	mouse_exited.connect(func():
		_hover = false
		queue_redraw())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(charm_id)

func _draw() -> void:
	var def := Charms.get_def(charm_id)
	var col: Color = def.color
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	# Square pixel badge: ink rim, coloured border, dark well, icon.
	var grow := 2.0 if _hover else 0.0
	var box := Rect2(c - Vector2(r, r) - Vector2(grow, grow), Vector2(r, r) * 2.0 + Vector2(grow, grow) * 2.0)
	draw_rect(box, PixelCard.INK)
	draw_rect(box.grow(-2), col)
	draw_rect(box.grow(-5), Color(0.06, 0.08, 0.11))
	draw_rect(box.grow(-5), Color(col, 0.16))
	Glyph.paint(self, def.icon, c, r * 0.68, col)
