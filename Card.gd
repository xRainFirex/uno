# ==========================================
# FILE: Card.gd
# DESCRIPTION: Visual controller for the Card.tscn UI element. Handles asymmetric visuals using self_modulate to preserve child contrast.
# VERSION: v0.018
# LAST EDITED: v0.018
# ==========================================
extends Button

# 1. @export data
# DESCRIPTION: Use a generic Resource export to prevent scope resolution errors during load.
# LAST EDITED: v0.013
@export var data: Resource 

@onready var label = $InnerColor/Label
@onready var inner_panel = $InnerColor

signal card_selected(card_node)

var hovered_state: bool = false
var is_interactive: bool = true

# 7. update_visuals
# DESCRIPTION: Updates the text and inner rounded background. Uses self_modulate for borders and white text overrides for Wild cards.
# LAST EDITED: v0.018
func update_visuals(is_back: bool = false):
	pivot_offset = size / 2.0
	is_interactive = !is_back
	
	if is_back:
		# AI Card / Deck Back: Black border (root) with white interior
		self.self_modulate = Color.BLACK
		inner_panel.self_modulate = Color.WHITE
		
		label.text = "UNO"
		label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1)) 
		label.add_theme_constant_override("outline_size", 0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	# Player Card / Discard: White border (root) with coloured interior
	self.self_modulate = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	var card_data = data as xCardData
	if not card_data: 
		return

	# 1. Update Text
	if card_data.type == xCardData.Type.NUMBER:
		label.text = str(card_data.value)
		label.add_theme_font_size_override("font_size", 32)
	else:
		var type_name = xCardData.Type.keys()[card_data.type].replace("_", " ")
		label.text = type_name
		label.add_theme_font_size_override("font_size", 20 if type_name.length() > 8 else 24)
	
	# 2. Update Colour and Text Colour
	var visual_colour: Color
	var text_colour: Color = Color.WHITE 
	
	match card_data.card_color:
		xCardData.CardColor.RED: visual_colour = Color(0.9, 0.1, 0.1)
		xCardData.CardColor.BLUE: visual_colour = Color(0.1, 0.1, 0.9)
		xCardData.CardColor.GREEN: visual_colour = Color(0.1, 0.7, 0.1)
		xCardData.CardColor.YELLOW: 
			visual_colour = Color(0.9, 0.8, 0.1)
			text_colour = Color.BLACK
		_: 
			# Wild Card: Dark background, Strict White text override
			visual_colour = Color(0.15, 0.15, 0.15)
			text_colour = Color(1, 1, 1, 1) # Forced white
			
	# Use self_modulate so the panel color doesn't affect the label modulation
	inner_panel.self_modulate = visual_colour
	label.add_theme_color_override("font_color", text_colour)

# 8. _on_pressed
# DESCRIPTION: Internal Godot signal handler for card clicks.
# LAST EDITED: v0.001
func _on_pressed():
	if is_interactive:
		card_selected.emit(self)

# 14. _on_mouse_entered
# DESCRIPTION: Triggers the hover animation.
# LAST EDITED: v0.010
func _on_mouse_entered():
	if not is_interactive: return
	hovered_state = true
	z_index = 10
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", -50.0, 0.15)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15)

# 15. _on_mouse_exited
# DESCRIPTION: Resets the card position.
# LAST EDITED: v0.010
func _on_mouse_exited():
	if not is_interactive: return
	hovered_state = false
	z_index = 0
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", 0.0, 0.15)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
