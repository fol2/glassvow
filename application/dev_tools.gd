class_name DevTools
extends RefCounted
## Production gate for the excluded Development tree. Stays packed so a
## store/RC build can ask whether the boot handler is present; it never
## preloads that tree.

const BOOT: String = "res://presentation/dev/boot.gd"
const CONSOLE: String = "res://presentation/dev/console.gd"
## Test seam. `null` keeps the live gate; a bool forces it.
static var forced: Variant = null


static func available() -> bool:
	if typeof(forced) == TYPE_BOOL:
		return forced
	return ResourceLoader.exists(BOOT) and (
			OS.has_feature("editor") or OS.has_feature("dev_tools"))
