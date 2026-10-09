# ==========================================
# FILE: Story.gd
# DESCRIPTION: The run's premise. You owe the Dealer a debt, split into three markers held by the three act
#              bosses. Beat a boss to win back its marker; win all three and the debt is paid in full.
# VERSION: v0.100
# ==========================================
class_name Story
extends RefCounted

const TAGLINE := "...a debt paid in full"

const PROLOGUE := [
	"One bad night at the Dealer's table cost you everything you had, and then some.",
	"Now you owe the House a debt no honest work could ever repay. The Dealer has written it on three markers and handed them to his three keepers: one in the Back Alley, one in the Velvet Casino, and the last in the Hall of Quietus.",
	"He has made you an offer. Win them back, hand by hand. Beat each keeper and their marker is yours to tear up.",
	"Clear all three and you earn your quietus: a debt paid in full.",
]

# markers_owed
# DESCRIPTION: How many markers are still held by the House (one per act boss not yet beaten).
static func markers_owed() -> int:
	return maxi(0, RunState.ACTS - int(RunState.stats.get("bosses", 0)))

static func markers_text(n: int) -> String:
	return "%d MARKER%s" % [n, "" if n == 1 else "S"]

# panel
# DESCRIPTION: The prologue as a modal panel. `on_close` runs when the player dismisses it.
static func panel(button_text: String, on_close: Callable) -> Control:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(UIKit.dimmer(0.85))
	var box := UIKit.panel(28)
	box.custom_minimum_size = Vector2(900, 0)
	layer.add_child(UIKit.centered(box))
	var col := UIKit.vbox(18)
	box.add_child(col)
	var icon := Glyph.new("text:Q", UIKit.GOLD, 72)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(icon)
	col.add_child(UIKit.title("THE DEBT", 48, UIKit.GOLD))
	for i in PROLOGUE.size():
		var l := UIKit.label(PROLOGUE[i], 22, UIKit.GOLD if i == PROLOGUE.size() - 1 else UIKit.TEXT, false, HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 840
		col.add_child(l)
	col.add_child(UIKit.spacer(0, 6))
	var b := UIKit.button(button_text, "AccentButton", Vector2(260, 60))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		layer.queue_free()
		on_close.call())
	col.add_child(b)
	return layer
