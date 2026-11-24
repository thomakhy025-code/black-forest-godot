extends Node
## Pooled players and tones built once. A hit no longer allocates a stream.

const ACCENT := {
	"fireball": 190.0,
	"ice": 780.0,
	"firesword": 150.0,
	"lightning": 1280.0,
	"mega": 78.0,
	"saber": 560.0,
	"swing": 210.0,
	"swing_fire": 160.0,
	"chop": 140.0,
	"crack": 90.0,
	"throw": 490.0,
	"dash": 920.0,
	"explode": 96.0,
	"hop": 640.0,
	"hit": 128.0,
	"kill": 84.0,
}

const _TRACK := {
	"firesword": true,
	"lightning": true,
	"dash": true,
	"saber": true,
	"fireball": true,
	"ice": true,
	"mega": true,
	"swing_fire": true,
	"chop": true,
	"crack": true,
}

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _wavs := {}
var _tones := {}
var _bed: AudioStreamPlayer


func _ready() -> void:
	for _i in 12:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_bed = AudioStreamPlayer.new()
	_bed.name = "Bed"
	add_child(_bed)
	for id in ACCENT.keys():
		if id == "saber":
			_tones[id] = _synth("saber")
		elif _TRACK.has(id):
			_tones[id] = _synth(id)
		else:
			_tones[id] = _tone(float(ACCENT[id]), 0.16 if id == "kill" or id == "mega" else 0.09, id == "hit" or id == "kill" or id == "explode" or id == "mega")
	_tones["saber_hum"] = _synth("saber_hum")
	_tones["mega_rumble"] = _synth("mega_rumble")


func play(id: String, volume_db: float = -6.0) -> void:
	if _players.is_empty():
		return
	if id == "saber_hum":
		_start_bed(id, -12.0)
		return
	if id == "mega_rumble":
		_start_bed(id, -14.0)
		return
	var loud := volume_db
	if id == "kill" or id == "mega" or id == "explode" or id == "saber":
		loud = -1.5
	elif id == "crack":
		loud = -2.0
	elif id == "hit" or id == "swing" or id == "swing_fire" or id == "fireball" or id == "chop":
		loud = -3.5
	elif id == "ice" or id == "firesword" or id == "lightning" or id == "dash":
		loud = -4.5
	if _TRACK.has(id) and _tones.has(id):
		_fire(_tones[id], loud, 1.0)
		return
	var path := "res://assets/audio/%s.wav" % id
	var use_file := id != "saber"
	if use_file and not _wavs.has(id) and ResourceLoader.exists(path):
		_wavs[id] = load(path)
	if use_file and _wavs.has(id):
		_fire(_wavs[id], loud, randf_range(0.94, 1.07))
	if _tones.has(id):
		if id == "saber":
			_fire(_tones[id], loud, 1.0)
		else:
			_fire(_tones[id], loud - 1.5, randf_range(0.92, 1.08))


func stop_bed() -> void:
	if _bed:
		_bed.stop()


func _start_bed(id: String, db: float) -> void:
	if _bed == null or not _tones.has(id):
		return
	_bed.stop()
	_bed.stream = _tones[id]
	_bed.volume_db = db
	_bed.pitch_scale = 1.0
	_bed.play()


func _fire(stream: AudioStream, db: float, pitch: float) -> void:
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stop()
	player.stream = stream
	player.volume_db = db
	player.pitch_scale = pitch
	player.play()


func _tone(start_hz: float, seconds: float, noise: bool) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var k := float(i) / float(count)
		var freq := lerpf(start_hz, start_hz * 0.45, k)
		phase += TAU * freq / float(rate)
		var env := (1.0 - k) * (1.0 - k)
		var sample := sin(phase) * env * 0.55 + sin(phase * 2.0) * env * 0.16
		if noise:
			var hash := float((i * 1103515245 + 12345) & 2047) / 1023.0 - 1.0
			sample += hash * env * 0.42
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _hash(i: int) -> float:
	return float((i * 1103515245 + 12345) & 2047) / 1023.0 - 1.0


func _bell(t: float, start: float, freq: float) -> float:
	var x := t - start
	if x < 0.0:
		return 0.0
	return sin(TAU * freq * x) * exp(-x * 5.2) * 0.34


func _synth(kind: String) -> AudioStreamWAV:
	var seconds := 0.4
	match kind:
		"firesword":
			seconds = 0.55
		"lightning":
			seconds = 0.28
		"dash":
			seconds = 0.2
		"saber":
			seconds = 0.5
		"saber_hum":
			seconds = 3.05
		"fireball":
			seconds = 0.46
		"ice":
			seconds = 0.82
		"mega":
			seconds = 0.62
		"mega_rumble":
			seconds = 2.55
		"swing_fire":
			seconds = 0.18
		"chop":
			seconds = 0.14
		"crack":
			seconds = 0.3
	var rate := 22050
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := [0.0, 0.0, 0.0]
	for i in count:
		var k := float(i) / float(count)
		var sample := _voice(kind, k, i, rate, phase)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 28000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _voice(kind: String, k: float, i: int, rate: int, phase: Array) -> float:
	var n := _hash(i)
	var step := TAU / float(rate)
	if kind == "firesword":
		phase[0] += step * 146.83
		phase[1] += step * 174.61
		phase[2] += step * 220.0
		var warm := sin(phase[0]) * 0.28 + sin(phase[1]) * 0.2 + sin(phase[2]) * 0.14
		return (warm + n * 0.4) * sin(k * PI)
	if kind == "lightning":
		phase[0] += step * lerpf(1860.0, 380.0, k)
		var env := pow(1.0 - k, 1.6)
		var crack := n * (1.0 if k < 0.18 else 0.22)
		return (sin(phase[0]) * 0.34 + crack * 0.72) * env
	if kind == "dash":
		phase[0] += step * lerpf(240.0, 1280.0, k)
		return (n * 0.62 + sin(phase[0]) * 0.22) * sin(k * PI)
	if kind == "saber_hum":
		phase[0] += step * 659.25
		phase[1] += step * 987.77
		var hold := 1.0
		if k < 0.03:
			hold = k / 0.03
		elif k > 0.9:
			hold = (1.0 - k) / 0.1
		var trem := 0.82 + 0.18 * sin(k * TAU * 5.0)
		return (sin(phase[0]) * 0.22 + sin(phase[1]) * 0.16 + sin(phase[0] * 2.0) * 0.05) * hold * trem
	if kind == "fireball":
		phase[0] += step * lerpf(180.0, 90.0, k)
		return (n * 0.62 + sin(phase[0]) * 0.28) * sin(clampf(k * 1.15, 0.0, 1.0) * PI)
	if kind == "ice":
		var t := k * 0.82
		return _bell(t, 0.0, 1046.5) + _bell(t, 0.12, 1318.5) + _bell(t, 0.26, 1568.0) + _bell(t, 0.42, 2093.0) * 0.45
	if kind == "mega_rumble":
		phase[0] += step * lerpf(40.0, 92.0, k * k)
		return (sin(phase[0]) * 0.5 + n * 0.28) * clampf(k * 1.3, 0.0, 1.0)
	if kind == "swing_fire":
		phase[0] += step * 196.0
		return (n * 0.7 + sin(phase[0]) * 0.25) * pow(1.0 - k, 2.0)
	if kind == "chop":
		phase[0] += step * lerpf(220.0, 90.0, k)
		var knock := sin(phase[0]) * 0.46
		var bite := n * (0.85 if k < 0.12 else 0.2)
		return (knock + bite) * pow(1.0 - k, 1.4)
	if kind == "crack":
		phase[0] += step * lerpf(160.0, 48.0, k)
		phase[1] += step * lerpf(420.0, 110.0, k)
		var snap := n * (1.0 if k < 0.08 else 0.35)
		var body := sin(phase[0]) * 0.4 + sin(phase[1]) * 0.16
		return (body + snap) * pow(1.0 - k, 1.15)
	phase[0] += step * lerpf(78.0, 32.0, k)
	phase[1] += step * lerpf(117.0, 48.0, k)
	phase[2] += step * 740.0
	var boom := 1.0
	if k < 0.02:
		boom = k / 0.02
	else:
		boom = pow(1.0 - k, 1.35)
	var bright := sin(phase[2]) * pow(1.0 - k, 4.0) * 0.18
	return (sin(phase[0]) * 0.46 + sin(phase[1]) * 0.22 + n * 0.52) * boom + bright
