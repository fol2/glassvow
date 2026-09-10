class_name Rng
extends RefCounted
## Mulberry32 PRNG — byte-exact port of the web engine's makeRng (engine.js).


var _state: int = 0


func _init(seed: int) -> void:
	_state = seed & 0xFFFFFFFF


func next() -> float:
	_state = (_state + 0x6D2B79F5) & 0xFFFFFFFF
	var t: int = _imul(_state ^ (_state >> 15), _state | 1)
	t = ((t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF) ^ t
	var u: int = t ^ (t >> 14)
	return float(u) / 4294967296.0


## Low-32 product: int64 wrap preserves those bits, so the mask is exact.
func _imul(a: int, b: int) -> int:
	return (a * b) & 0xFFFFFFFF


func get_state() -> int:
	if _state >= 0x80000000:
		return _state - 0x100000000
	return _state


func pick_index(n: int) -> int:
	return int(floorf(next() * float(n)))


func irange(a: int, b: int) -> int:
	return a + int(floorf(next() * float(b - a + 1)))


func shuffle_indices(n: int) -> Array[int]:
	var a: Array[int] = []
	a.resize(n)
	for i: int in range(n):
		a[i] = i
	for i: int in range(n - 1, 0, -1):
		var j: int = int(floorf(next() * float(i + 1)))
		var tmp: int = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a
