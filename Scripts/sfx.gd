class_name Sfx

# ============================================
# SFX HELPER
# ============================================
# Small helpers for building AudioStreamPlayers
# in code, so scenes do not need new nodes added
# (which Godot can clobber when it re-saves).
#
# Everything defaults to the SFX bus, so the
# Sound Effects slider controls it.
# ============================================


static func make(parent: Node, stream: AudioStream = null,
		bus: String = "SFX") -> AudioStreamPlayer:

	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	parent.add_child(p)
	return p


## Plays with a little random pitch so repeats
## do not sound like the same file every time.
static func play(p: AudioStreamPlayer, stream: AudioStream = null,
		lo: float = 0.96, hi: float = 1.04) -> void:

	if p == null:
		return

	if stream != null:
		p.stream = stream

	if p.stream == null:
		return

	p.pitch_scale = randf_range(lo, hi)
	p.play()


## Restarts the clip whenever it ends, until
## stop_loop() is called. Used for sounds that
## run for the length of an animation.
static func start_loop(p: AudioStreamPlayer) -> void:

	if p == null or p.stream == null:
		return

	if not p.finished.is_connected(_repeat.bind(p)):
		p.finished.connect(_repeat.bind(p))

	p.pitch_scale = 1.0
	p.play()


static func stop_loop(p: AudioStreamPlayer) -> void:

	if p == null:
		return

	if p.finished.is_connected(_repeat.bind(p)):
		p.finished.disconnect(_repeat.bind(p))

	p.stop()


static func _repeat(p: AudioStreamPlayer) -> void:
	if is_instance_valid(p):
		p.play()
