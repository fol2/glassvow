class_name StatusRow
extends HBoxContainer
## The row of StatusChips an actor carries. A parallel port of the benchmark's
## `.status-row { display:flex; gap:6px }`.
##
## The 6px gap is not spacing taste: `.schip .n` hangs its numeral 2px past the
## chip's right edge, and the gap is what absorbs that overhang. This is why
## StatusChip stays a clean 32px box instead of padding itself out of the way.
##
## Real child nodes rather than one `_draw()`. Each chip owns a tooltip, and a
## tooltip is precisely the case the node-per-layer rule keeps nodes for —
## see docs/solutions/design-patterns/dom-node-per-layer-in-godot.md.

## `.status-row { gap: 6px }`
const GAP: int = 6

## Which statuses are on screen, in the order shown. Kept so that a count change
## — the common case, on every single sync — updates in place rather than
## rebuilding the row and discarding every tooltip along with it.
var _shown: Array[StringName] = []


func _init() -> void:
	add_theme_constant_override("separation", GAP)
	alignment = BoxContainer.ALIGNMENT_CENTER
	# The row is a layout box, not a target. Its chips are MOUSE_FILTER_PASS and
	# still hit-test themselves, so the hover lands on the chip that owns it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `infos` is the content status table — `{id: {name, desc}}` — and only feeds
## the hover text. A caller with no ContentDB to hand passes `{}` and still gets
## chips; the icon and the count need nothing but the id.
func sync(statuses: Dictionary, infos: Dictionary = {}) -> void:
	var ids: Array[StringName] = []
	var counts: Array[int] = []
	# Insertion order, not sorted. The benchmark renders the object in whatever
	# order the rules put the statuses there, and a row that reshuffles itself
	# when one condition expires is a row the eye has to read again from scratch.
	for k: Variant in statuses.keys():
		var n: int = statuses[k]
		if n != 0:
			ids.append(StringName(str(k)))
			counts.append(n)

	if ids == _shown:
		for i: int in range(counts.size()):
			var chip: StatusChip = get_child(i) as StatusChip
			chip.set_count(counts[i])
		return

	# remove_child before queue_free: a queued node is still a child until the
	# frame ends, so get_child(i) above would otherwise index the dead row.
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for i: int in range(ids.size()):
		var info: Dictionary = infos.get(ids[i], {})
		add_child(StatusChip.new(ids[i], counts[i], info))
	_shown = ids
