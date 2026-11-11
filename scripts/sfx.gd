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
	"throw": 490.0,
	"dash": 920.0,
	"explode": 96.0,
	"hop": 640.0,
	"hit": 128.0,
	"kill": 84.0,
}

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _wavs := {}
var _tones := {}


func _ready() -> void:
	for _i in 12:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	for id in ACCENT.keys():
		_tones[id] = _tone(float(ACCENT[id]), 0.16 if id == "kill" or id == "mega" else 0.09, id == "hit" or id == "kill" or id == "explode" or id == "mega")


func play(id: String, volume_db: float = -6.0) -> void:
	if _players.is_empty():
		return
	var loud := volume_db
	if id == "kill" or id == "mega" or id == "explode":
		loud = -1.5
	elif id == "hit" or id == "swing" or id == "swing_fire" or id == "fireball":
		loud = -3.5
	var path := "res://assets/audio/%s.wav" % id
	if not _wavs.has(id) and ResourceLoader.exists(path):
		_wavs[id] = load(path)
	if _wavs.has(id):
		_fire(_wavs[id], loud, randf_range(0.94, 1.07))
	if _tones.has(id):
		_fire(_tones[id], loud - 1.5, randf_range(0.92, 1.08))


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
