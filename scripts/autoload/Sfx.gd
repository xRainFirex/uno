# ==========================================
# FILE: Sfx.gd
# DESCRIPTION: Autoload that synthesises small sound effects at startup, so the game needs no audio assets.
# VERSION: v0.100
# ==========================================
extends Node

const RATE := 22050

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["card"] = _swish(0.11, 0.45)
	_streams["play"] = _mix([_swish(0.07, 0.35), _tone([170.0], 0.09, 0.5, 0.0)])
	_streams["click"] = _tone([1100.0], 0.035, 0.22, 0.2)
	_streams["hover"] = _tone([1600.0], 0.02, 0.06, 0.0)
	_streams["coin"] = _tone([1318.5, 1975.5], 0.07, 0.25, 0.3)
	_streams["call"] = _tone([659.3, 987.8, 1318.5], 0.09, 0.3, 0.4)
	_streams["power"] = _tone([392.0, 523.3, 659.3], 0.06, 0.25, 0.5)
	_streams["win"] = _tone([523.3, 659.3, 784.0, 1046.5], 0.13, 0.3, 0.4)
	_streams["lose"] = _tone([392.0, 329.6, 261.6, 196.0], 0.16, 0.3, 0.4)
	_streams["hurt"] = _mix([_tone([140.0, 90.0], 0.08, 0.45, 0.7), _swish(0.12, 0.3)])
	_streams["error"] = _tone([180.0, 150.0], 0.06, 0.25, 0.8)
	_streams["heal"] = _tone([523.3, 784.0], 0.08, 0.2, 0.0)
	for k in _streams.keys():
		_streams[k] = _to_stream(_streams[k])

# play
# DESCRIPTION: Plays a named effect with optional pitch variation.
func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not RunState.sound_on or not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.volume_db = volume_db
	p.play()

# _tone
# DESCRIPTION: A sequence of short notes with a soft square/sine blend.
func _tone(freqs: Array, note_len: float, volume: float, square: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(note_len * RATE)
	for f in freqs:
		var phase := 0.0
		for i in n:
			var t := float(i) / RATE
			phase += f / RATE
			var s := sin(phase * TAU)
			var sq := 1.0 if s >= 0.0 else -1.0
			var env := minf(1.0, t / 0.004) * exp(-t * 5.0 / note_len)
			out.append((s * (1.0 - square) + sq * square * 0.5) * env * volume)
	return out

# _swish
# DESCRIPTION: Filtered noise burst, like a card sliding on felt.
func _swish(length: float, volume: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(length * RATE)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var cutoff := lerpf(0.5, 0.08, t)
		lp += (randf_range(-1.0, 1.0) - lp) * cutoff
		var env := sin(t * PI) * (1.0 - t * 0.5)
		out.append(lp * env * volume * 2.0)
	return out

func _mix(parts: Array) -> PackedFloat32Array:
	var length := 0
	for p in parts:
		length = maxi(length, p.size())
	var out := PackedFloat32Array()
	out.resize(length)
	for p in parts:
		for i in p.size():
			out[i] += p[i]
	return out

func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
