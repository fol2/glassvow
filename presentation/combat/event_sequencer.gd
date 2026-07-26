class_name EventSequencer
extends RefCounted
## Await-pump over GameEvent batches (plan M5): one event at a time, in
## order; the screen locks input while the pump is busy. The engine mutates
## state to the END of a batch before events return, so handlers must render
## from event-carried fields — live state is only safe once `busy_changed`
## goes false.
##
## `instant` (headless tests) makes the whole drain synchronous: handlers
## must not execute any `await` when it is set.

signal busy_changed(busy: bool)

## func(ev: Dictionary) -> void; may await tweens/timers when not instant.
var handler: Callable
var instant: bool = false
var _queue: Array[Dictionary] = []
var _busy: bool = false


func is_busy() -> bool:
	return _busy


## How many events of type `t` this one heads, counting itself. A wave of draws
## is paced by how big the wave is (`drawBatchSchedule`, pile-chrome.js:91), and
## a handler that only ever sees one event at a time cannot know that without
## asking. Only meaningful from inside `handler`, where the current event has
## already left the queue.
func run_length(t: StringName) -> int:
	var n: int = 1
	for ev: Dictionary in _queue:
		if ev["t"] != t:
			break
		n += 1
	return n


func enqueue(events: Array[Dictionary]) -> void:
	_queue.append_array(events)
	if not _busy:
		_pump()


func _pump() -> void:
	_busy = true
	busy_changed.emit(true)
	while not _queue.is_empty():
		var ev: Dictionary = _queue.pop_front()
		if instant:
			handler.call(ev)  # coroutine with no taken awaits completes inline
		else:
			await handler.call(ev)
	_busy = false
	busy_changed.emit(false)
