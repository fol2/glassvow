class_name DevTools
extends RefCounted
## Production gate for the excluded Development tree. Stays packed so a
## store/RC build can ask whether the boot handler is present; it never
## preloads that tree.

const BOOT: String = "res://presentation/dev/boot.gd"


static func available() -> bool:
	return ResourceLoader.exists(BOOT) and (
			OS.has_feature("editor") or OS.has_feature("dev_tools"))
