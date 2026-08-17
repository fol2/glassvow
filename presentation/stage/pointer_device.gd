class_name PointerDevice
extends RefCounted
## `matchMedia('(pointer: coarse)')` — a touchscreen with no mouse.
##
## Pure by construction: `coarse_for` is the predicate; `coarse` reads live
## DisplayServer state unless a test has declared otherwise.


## When true, `coarse()` returns `_declared_coarse` instead of querying the OS.
static var _declared: bool = false
static var _declared_coarse: bool = false


static func coarse() -> bool:
	if _declared:
		return _declared_coarse
	return coarse_for(
		DisplayServer.is_touchscreen_available(),
		DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE),
	)


## Pure seam for headless tests and call sites that already know the device.
static func coarse_for(touchscreen: bool, has_mouse: bool) -> bool:
	return touchscreen and not has_mouse


## Declare coarse/fine for the duration of one test case. Always pair with
## `clear_declaration()`.
static func declare_coarse(is_coarse: bool) -> void:
	_declared = true
	_declared_coarse = is_coarse


static func clear_declaration() -> void:
	_declared = false
