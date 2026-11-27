extends Node

signal sfx_toggled(enabled: bool)

const SAMPLE_RATE: int = 22050
const MAX_PLAYERS: int = 8
const SPAM_COOLDOWN_MS: int = 40

var _players: Array[AudioStreamPlayer] = []
var _next_player_idx: int = 0
var _streams: Dictionary = {}
var _last_played_ms: Dictionary = {}


func _ready() -> void:
	for i in range(MAX_PLAYERS):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)

	_generate_all_sfx()


func is_sfx_enabled() -> bool:
	if Engine.has_singleton("SaveManager") or has_node("/root/SaveManager"):
		return SaveManager.is_sfx_enabled()
	return true


func toggle_sfx() -> bool:
	var new_state: bool = not SaveManager.is_sfx_enabled()
	SaveManager.set_sfx_enabled(new_state)
	sfx_toggled.emit(new_state)
	if new_state:
		play_select()
	return new_state


func play_select() -> void:
	_play_sfx("select", -8.0)


func play_send() -> void:
	_play_sfx("send", -8.0)


func play_capture() -> void:
	_play_sfx("capture", -5.0)


func play_lost() -> void:
	_play_sfx("lost", -5.0)


func play_portal() -> void:
	_play_sfx("portal", -6.0)


func play_skill() -> void:
	_play_sfx("skill", -4.0)


func play_victory() -> void:
	_play_sfx("victory", -4.0)


func play_defeat() -> void:
	_play_sfx("defeat", -4.0)


func play_boss_skill() -> void:
	_play_sfx("boss_skill", -3.0)


func _play_sfx(key: String, vol_db: float = -6.0) -> void:
	if not SaveManager.is_sfx_enabled():
		return
	if not _streams.has(key) or _players.is_empty():
		return

	var now_ms: int = Time.get_ticks_msec()
	var prev_ms: int = int(_last_played_ms.get(key, -9999))
	if now_ms - prev_ms < SPAM_COOLDOWN_MS:
		return
	_last_played_ms[key] = now_ms

	var chosen: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			chosen = p
			break
	if chosen == null:
		chosen = _players[_next_player_idx]
		_next_player_idx = (_next_player_idx + 1) % _players.size()

	chosen.stream = _streams[key]
	chosen.volume_db = vol_db
	chosen.play()


func _generate_all_sfx() -> void:
	_streams["select"] = _gen_select()
	_streams["send"] = _gen_send()
	_streams["capture"] = _gen_capture()
	_streams["lost"] = _gen_lost()
	_streams["portal"] = _gen_portal()
	_streams["skill"] = _gen_skill()
	_streams["victory"] = _gen_victory()
	_streams["defeat"] = _gen_defeat()
	_streams["boss_skill"] = _gen_boss_skill()


func _gen_select() -> AudioStreamWAV:
	var dur: float = 0.09
	var count: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / dur
		var freq: float = lerpf(880.0, 1320.0, progress)
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = minf(1.0, t / 0.006) * pow(1.0 - progress, 1.8)
		buf[i] = sin(phase) * env * 0.45
	return _build_wav(buf)


func _gen_send() -> AudioStreamWAV:
	var dur: float = 0.14
	var count: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var lp: float = 0.0
	var phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / dur
		var freq: float = lerpf(420.0, 210.0, progress)
		phase += TAU * freq / float(SAMPLE_RATE)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.18)
		var tri: float = (2.0 / PI) * asin(sin(phase))
		var env: float = minf(1.0, t / 0.012) * pow(1.0 - progress, 1.5)
		buf[i] = (lp * 0.55 + tri * 0.25) * env * 0.5
	return _build_wav(buf)


func _gen_capture() -> AudioStreamWAV:
	return _gen_arpeggio([523.25, 659.25, 783.99], 0.075, 0.28, false)


func _gen_lost() -> AudioStreamWAV:
	return _gen_arpeggio([246.94, 164.81], 0.12, 0.30, true)


func _gen_portal() -> AudioStreamWAV:
	var dur: float = 0.24
	var count: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase: float = 0.0
	var lfo_phase: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / dur
		lfo_phase += TAU * 28.0 / float(SAMPLE_RATE)
		var freq: float = lerpf(520.0, 1080.0, progress) + sin(lfo_phase) * 75.0
		phase += TAU * freq / float(SAMPLE_RATE)
		var env: float = minf(1.0, t / 0.015) * pow(1.0 - progress, 1.4)
		buf[i] = (sin(phase) * 0.65 + sin(phase * 1.5) * 0.35) * env * 0.42
	return _build_wav(buf)


func _gen_skill() -> AudioStreamWAV:
	var dur: float = 0.32
	var count: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phase1: float = 0.0
	var phase2: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / dur
		var f1: float = lerpf(330.0, 660.0, progress)
		var f2: float = lerpf(495.0, 990.0, progress)
		phase1 += TAU * f1 / float(SAMPLE_RATE)
		phase2 += TAU * f2 / float(SAMPLE_RATE)
		var tri1: float = (2.0 / PI) * asin(sin(phase1))
		var env: float = minf(1.0, t / 0.015) * pow(1.0 - progress, 1.3)
		buf[i] = (tri1 * 0.55 + sin(phase2) * 0.45) * env * 0.48
	return _build_wav(buf)


func _gen_victory() -> AudioStreamWAV:
	return _gen_arpeggio([523.25, 659.25, 783.99, 1046.50], 0.11, 0.58, false)


func _gen_defeat() -> AudioStreamWAV:
	return _gen_arpeggio([392.00, 311.13, 261.63], 0.16, 0.56, true)


func _gen_boss_skill() -> AudioStreamWAV:
	var dur: float = 0.48
	var count: int = int(dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var lp: float = 0.0
	var phase_low: float = 0.0
	var phase_sub: float = 0.0
	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var progress: float = t / dur
		var f_low: float = lerpf(130.0, 58.0, progress)
		var f_sub: float = lerpf(195.0, 88.0, progress)
		phase_low += TAU * f_low / float(SAMPLE_RATE)
		phase_sub += TAU * f_sub / float(SAMPLE_RATE)
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.10)
		var tri_sub: float = (2.0 / PI) * asin(sin(phase_sub))
		var env: float = minf(1.0, t / 0.02) * pow(1.0 - progress, 1.2)
		buf[i] = clampf((sin(phase_low) * 0.55 + tri_sub * 0.30 + lp * 0.35) * env * 0.65, -0.95, 0.95)
	return _build_wav(buf)


func _gen_arpeggio(freqs: Array, step_sec: float, total_dur: float, use_triangle: bool) -> AudioStreamWAV:
	var count: int = int(total_dur * SAMPLE_RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	var phases := PackedFloat32Array()
	phases.resize(freqs.size())

	for i in range(count):
		var t: float = float(i) / float(SAMPLE_RATE)
		var sample: float = 0.0
		for n_idx in range(freqs.size()):
			var start_t: float = float(n_idx) * step_sec
			if t < start_t:
				continue
			var local_t: float = t - start_t
			var note_dur: float = total_dur - start_t
			var freq: float = float(freqs[n_idx])
			phases[n_idx] += TAU * freq / float(SAMPLE_RATE)
			var wave: float = (2.0 / PI) * asin(sin(phases[n_idx])) if use_triangle else sin(phases[n_idx])
			var env: float = minf(1.0, local_t / 0.01) * pow(maxf(0.0, 1.0 - local_t / maxf(0.05, note_dur)), 1.4)
			sample += wave * env * 0.32
		buf[i] = clampf(sample, -0.95, 0.95)
	return _build_wav(buf)


func _build_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v: int = clampi(int(round(samples[i] * 32767.0)), -32767, 32767)
		data.encode_s16(i * 2, v)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav
