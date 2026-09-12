extends RefCounted
## One geometry job owns this token; no gameplay or global state.
var _mutex: Mutex = Mutex.new()
var _cancelled: bool = false
func cancel() -> void:
	_mutex.lock()
	_cancelled=true
	_mutex.unlock()
func cancelled() -> bool:
	_mutex.lock()
	var result: bool = _cancelled
	_mutex.unlock()
	return result
