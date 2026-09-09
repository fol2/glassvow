extends "res://uncached_greedy_policy.gd"
## Exact query-local memoisation only. Never survives an action or native step.
var _memo_game: GlassvowGame = null
var _memo_features: Dictionary = {}
var _memo_copies: Dictionary = {}

func choose_action(g: GlassvowGame) -> Dictionary:
 assert(_memo_game == null)
 _memo_game = g
 _memo_features = {}
 _memo_copies = {}
 var answer: Dictionary = super.choose_action(g)
 _memo_game = null
 _memo_features = {}
 _memo_copies = {}
 return answer

func features(g: GlassvowGame) -> Dictionary:
 if _memo_game != g:
  return super.features(g)
 if _memo_features.is_empty():
  _memo_features = super.features(g)
 return _memo_features

func copies(g: GlassvowGame, id: String) -> int:
 if _memo_game != g:
  return super.copies(g, id)
 if not _memo_copies.has(id):
  _memo_copies[id] = super.copies(g, id)
 return int(_memo_copies[id])
