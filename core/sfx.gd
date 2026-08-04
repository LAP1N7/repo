class_name Sfx
extends Node

## 효과음. 파일이 있으면 그걸 쓰고, 없으면 그 자리에서 합성한다.
##
## ── 왜 합성 폴백이 있는가 ────────────────────────────────────────────────
## 아트와 같은 원칙이다. 에셋이 하나도 없어도 게임은 소리가 나야 하고, 파일을
## 하나씩 떨어뜨리면 그때부터 그게 대신 나와야 한다. 사운드가 "나중에 통째로
## 붙이는 것" 이 되면 타이밍·볼륨·중첩 문제를 마지막에 한꺼번에 만나게 된다.
##
## 합성음은 임시 대역이지 최종물이 아니다. 톤은 일부러 건조하게 잡았다 -
## 그럴듯하면 교체를 미루게 된다.
##
## ── 왜 재생기를 풀로 도는가 ──────────────────────────────────────────────
## 4배속 전투에서는 한 틱에 6명이 동시에 행동한다. 재생기가 하나면 뒤엣것이
## 앞엣것을 끊어서 타격감이 통째로 사라진다. 여러 개를 돌려 쓴다.
##
## ── 왜 같은 소리를 겹쳐 막는가 ───────────────────────────────────────────
## 같은 틱에 타격이 셋이면 같은 파형이 셋 겹쳐 진폭이 3배가 된다. 귀에는
## "커진 소리" 가 아니라 "깨진 소리" 로 들린다. 같은 이름은 짧은 시간 안에
## 한 번만 낸다.

const MIX_RATE: int = 22050
const VOICES: int = 8

## 같은 이름의 소리를 다시 낼 수 있게 되기까지의 시간(초).
const DEDUPE: float = 0.045

## 파일을 찾는 곳. 여기 같은 이름의 파일을 넣으면 합성음 대신 그게 나온다.
const DIR := "res://assets/sfx/"

## 음소거와 볼륨은 **정적**이다. 화면을 넘어가도 유지돼야 하는 사용자 설정인데,
## 인스턴스는 화면마다 새로 만들어지기 때문이다.
static var enabled: bool = true
static var volume_db: float = -6.0

## 배경음악은 효과음 풀과 따로 둔다.
##
## 풀을 돌려 쓰면 음악이 다음 효과음에 밀려 끊긴다. 그리고 음악은 화면을
## 넘어가도 이어져야 하는데(타이틀 → 상점), 그러려면 인스턴스가 아니라
## **정적**으로 하나만 살아 있어야 한다.
static var _music: AudioStreamPlayer = null
static var _music_name: String = ""

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary = {}      ## 이름 -> AudioStream
var _last_at: Dictionary = {}    ## 이름 -> 마지막 재생 시각
var _clock: float = 0.0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func _process(delta: float) -> void:
	_clock += delta


## 배경음악을 튼다. 같은 곡이 이미 돌고 있으면 아무것도 안 한다 -
## 화면이 바뀔 때마다 처음부터 다시 시작하면 음악이 계속 끊긴다.
func play_music(name: String) -> void:
	if _music_name == name and _music != null and is_instance_valid(_music):
		if not enabled:
			_music.stop()
		elif not _music.playing:
			_music.play()
		return

	var path := "res://assets/music/%s.mp3" % name
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if not (stream is AudioStream):
		return

	stop_music()
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	# 음악은 효과음보다 확실히 낮게 깔린다. 같은 볼륨이면 타격감이 묻힌다.
	_music.volume_db = volume_db - 8.0
	# 트리 루트에 붙인다. 화면이 사라져도 음악은 살아 있어야 한다.
	get_tree().root.add_child(_music)
	_music_name = name
	if enabled:
		_music.play()


func stop_music() -> void:
	if _music != null and is_instance_valid(_music):
		_music.stop()
		_music.queue_free()
	_music = null
	_music_name = ""


## 이름 하나로 낸다. 없는 이름이면 조용히 무시한다 -
## 소리 때문에 게임이 멈추는 일은 없어야 한다.
func play(name: String, pitch: float = 1.0) -> void:
	if not enabled or _players.is_empty():
		return
	if _clock - float(_last_at.get(name, -99.0)) < DEDUPE:
		return
	var stream := _stream_for(name)
	if stream == null:
		return
	_last_at[name] = _clock

	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func _stream_for(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]

	# 파일이 우선. .ogg → .wav 순으로 찾는다.
	for ext in [".ogg", ".wav"]:
		var path: String = DIR + name + ext
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				_cache[name] = res
				return res

	var made := _synth(name)
	_cache[name] = made
	return made


# ── 합성 ─────────────────────────────────────────────────────────────────
# 전부 정수·고정 파형이라 실행할 때마다 같은 소리가 난다. 결정론을 지킨다.

func _synth(name: String) -> AudioStream:
	match name:
		"step":      return _tone(180.0, 0.05, "square", 0.18, 0.6)
		# 근접과 원거리를 나눈다. 파일이 둘 다 있고, 무엇보다 화면을 안 봐도
		# 누가 때렸는지 소리로 갈린다.
		"attack_melee":  return _noise(0.07, 0.55, 2600.0)
		"attack_ranged": return _tone(880.0, 0.06, "square", 0.35, 0.35)
		"attack":    return _noise(0.07, 0.55, 2600.0)
		"hit":       return _noise(0.11, 0.75, 900.0)
		"death":     return _tone(320.0, 0.34, "saw", 0.5, 0.15)
		"heal":      return _tone(520.0, 0.20, "sine", 0.35, 2.0)
		"special":   return _tone(240.0, 0.42, "square", 0.45, 2.6)
		"defend":    return _noise(0.09, 0.35, 400.0)
		"click":     return _tone(660.0, 0.035, "square", 0.22, 1.0)
		"buy":       return _tone(440.0, 0.10, "sine", 0.30, 1.8)
		"victory":   return _tone(392.0, 0.55, "sine", 0.45, 2.4)
		"defeat":    return _tone(196.0, 0.70, "saw", 0.45, 0.4)
		"opening":   return _tone(330.0, 0.80, "sine", 0.40, 2.0)
	return null


## 한 음. end_ratio 가 1보다 크면 올라가고 작으면 내려간다.
func _tone(freq: float, sec: float, wave: String, amp: float,
		end_ratio: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * sec)
	var buf := PackedByteArray()
	buf.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var f: float = lerpf(freq, freq * end_ratio, t)
		phase += TAU * f / float(MIX_RATE)
		var v := 0.0
		match wave:
			"square": v = 1.0 if sin(phase) >= 0.0 else -1.0
			"saw":    v = fmod(phase / TAU, 1.0) * 2.0 - 1.0
			_:        v = sin(phase)
		# 뒤로 갈수록 줄어드는 감쇠. 끊기는 소리(클릭 노이즈)를 막는다.
		v *= amp * (1.0 - t) * (1.0 - t)
		_put(buf, i, v)
	return _wav(buf)


## 잡음 버스트. cutoff 가 높을수록 밝고 건조하다.
func _noise(sec: float, amp: float, cutoff: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * sec)
	var buf := PackedByteArray()
	buf.resize(n * 2)
	# 난수를 쓰지 않는다. 고정 시드 LCG 로 매번 같은 파형을 만든다.
	var seed_v: int = 12345
	var lp := 0.0
	var k: float = clampf(cutoff / float(MIX_RATE), 0.02, 0.9)
	for i in n:
		seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
		var raw := float(seed_v % 2000) / 1000.0 - 1.0
		lp += (raw - lp) * k
		var t := float(i) / float(n)
		_put(buf, i, lp * amp * (1.0 - t) * (1.0 - t))
	return _wav(buf)


func _put(buf: PackedByteArray, i: int, v: float) -> void:
	var s := int(clampf(v, -1.0, 1.0) * 32000.0)
	buf.encode_s16(i * 2, s)


func _wav(buf: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = buf
	return w
