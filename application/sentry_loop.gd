class_name GlassvowMainLoop
extends SceneTree
## Inits Sentry before the main scene. Auto Init is off so `before_send` can
## attach; `_initialize()` is still earlier than any game script.


## Numeric iOS CFBundleVersion. Must match both iOS export presets'
## `application/version` and `sentry/options/dist`. Not the marketing
## version (`application/config/version` / `application/short_version`).
const IOS_BUILD_NUMBER: String = "1"

var _privacy: SentryPrivacy = SentryPrivacy.new()


func _initialize() -> void:
	if OS.has_feature("editor"):
		return
	SentrySDK.init(_configure)


func _configure(options: SentryOptions) -> void:
	options.release = "io.fol2.glassvow@{app_version}"
	options.dist = IOS_BUILD_NUMBER
	options.before_send = _before_send


func _before_send(event: SentryEvent) -> SentryEvent:
	if event.get_environment().contains("editor"):
		return null
	var i: int = 0
	var n: int = event.get_exception_count()
	while i < n:
		event.set_exception_value(i, SentryPrivacy.redact(event.get_exception_value(i)))
		i += 1
	event.set_message(SentryPrivacy.redact(event.get_message()))
	if not event.is_crash():
		var key: String = event.get_exception_value(0) + "\n" + event.get_message()
		if not _privacy.allow_nonfatal(key):
			return null
	return event
