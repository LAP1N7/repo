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

## 효과음에만 더 얹는 감쇠.
##
## 타격·클릭이 배경음악을 덮었다. volume_db 를 통째로 내리면 음악까지 같이
## 작아지므로(음악은 volume_db 기준으로 다시 -8 을 먹는다) 효과음 쪽에만 뺀다.
const SFX_TRIM: float = -4.0

## 배경음악은 효과음 풀과 따로 둔다.
##
## 풀을 돌려 쓰면 음악이 다음 효과음에 밀려 끊긴다. 그리고 음악은 화면을
## 넘어가도 이어져야 하는데(타이틀 → 상점), 그러려면 인스턴스가 아니라
## **정적**으로 하나만 살아 있어야 한다.
static var _music: AudioStreamPlayer = null
static var _music_name: String = ""

## 브라우저 오디오가 열렸는가.
##
## ── 이걸 왜 따로 들고 있어야 하는가 ──────────────────────────────────
## 브라우저는 **첫 사용자 조작 전에는 소리를 못 내게 막는다.** 여기까지는
## 알려진 이야기인데, 진짜 함정은 그 다음이다. 잠긴 상태에서 play() 를 불러도
## AudioStreamPlayer 는 **playing == true 를 돌려준다.** 재생 위치도 정상적으로
## 흘러간다. 소리만 안 난다.
##
## 그래서 "playing 이 false 면 다시 튼다" 는 식의 복구 코드는 전부 속는다.
## 실제로 그렇게 두 번 고쳤다가 두 번 다 안 고쳐졌다.
##
## 효과음이 멀쩡했던 이유도 같다 - 효과음은 전부 버튼을 누른 뒤에 나므로 이미
## 열린 뒤였다. 배경음악만 타이틀이 뜨는 순간, 즉 조작 전에 걸렸다.
##
## 답은 playing 을 믿지 않는 것이다. 조작이 실제로 들어왔는지를 우리가 세고,
## 그 전에는 아예 play() 를 부르지 않는다.
##
## ── 조작 감지는 Sfx 밖에도 있어야 한다 ───────────────────────────────
## 처음에는 이 감지를 Sfx._input 에만 뒀는데, 로딩 화면에는 Sfx 인스턴스가
## 없어서 **스킵 클릭이 아무에게도 안 잡혔다.** 그 다음 타이틀에서 가만히
## 기다리면 조작이 하나도 세어지지 않아 영영 조용했다.
## 그래서 항상 살아 있는 Game 도 같이 센다. (view/game.gd 의 _input)
static var _unlocked: bool = false

## 마지막으로 음악을 튼 시각. 무한 재시작을 막는 데 쓴다.
static var _music_started_at: float = 0.0

## 재생 시도 횟수.
##
## play() 를 불렀는데 시작이 안 되는 경우가 있다. 한 번만 시도하면 거기서 끝이라
## 화면에는 "재생기 정지 상태" 만 남는다. 몇 번 더 두드려 본다.
## 무한히 두드리면 안 된다 - 진짜로 못 트는 환경에서는 매 프레임 재시작이 되고,
## 그건 무음과 구별이 안 된다.
static var _music_tries: int = 0
const MUSIC_MAX_TRIES: int = 4

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary = {}      ## 이름 -> AudioStream
var _last_at: Dictionary = {}    ## 이름 -> 마지막 재생 시각
var _clock: float = 0.0


## 화면이 바뀔 때마다 Sfx 인스턴스는 새로 만들어진다. 그때마다 음악이
## 아직 살아 있는지 확인하고, 죽어 있으면 되살린다.
##
## ── 왜 이게 필요했나 ─────────────────────────────────────────────────
## play_music 을 부르는 곳이 **타이틀 화면 하나뿐**이었다. 곡이 74초라
## 한 바퀴 돌고 나면 아무도 다시 틀어 주지 않아서, 상점이나 전투로 넘어간
## 뒤에는 영영 조용했다.
func _ready() -> void:
	resume_music()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func _process(delta: float) -> void:
	_clock += delta
	_retry_music()


## 시작에 실패한 음악을 몇 번 더 두드린다. (위 _music_tries 주석 참조)
func _retry_music() -> void:
	if _music_tries == 0 or _music_tries >= MUSIC_MAX_TRIES:
		return
	if _music == null or not is_instance_valid(_music) or _music.playing:
		return
	# Sample 경로에서는 playing 이 곧바로 false 로 돌아오는 경우가 있다.
	# 간격이 짧으면 소리는 나는데 매번 처음부터 다시 트는 상태가 된다.
	if float(Time.get_ticks_msec()) / 1000.0 - _music_started_at < 2.0:
		return
	resume_music()


func _input(e: InputEvent) -> void:
	mark_gesture(e)


## 오디오를 내보내도 되는가.
##
## 브라우저가 아니면 잠금 자체가 없다. 데스크톱에서까지 클릭을 기다리면
## 타이틀에서 가만히 있는 동안 음악이 안 나온다 - 실제로 그렇게 됐다.
static func audio_open() -> bool:
	return _unlocked or not OS.has_feature("web")


## 사용자 조작이면 잠금을 풀고 음악을 잇는다. 어디서 불러도 된다.
##
## 마우스 이동은 조작으로 안 친다 - 브라우저도 그건 제스처로 안 쳐 준다.
## 누른 것만 센다.
static func mark_gesture(e: InputEvent) -> void:
	if _unlocked:
		return
	var gesture: bool = (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) or (e is InputEventKey and (e as InputEventKey).pressed) or (e is InputEventScreenTouch)
	if not gesture:
		return
	_unlocked = true
	resume_music()


## 틀어야 할 곡이 있는데 안 울리고 있으면 튼다.
##
## 잠금이 풀리기 전에는 아무것도 안 한다. 여기서 play() 를 부르면 "재생 중인데
## 소리는 안 나는" 유령 상태로 들어가 버리고, 그 뒤로는 되살릴 방법이 없다.
##
## 정적이다. Sfx 인스턴스가 없는 화면(로딩)에서도 불러야 하기 때문이다.
static func resume_music() -> void:
	if not audio_open() or not enabled or _music_name == "":
		return
	if _music == null or not is_instance_valid(_music) or _music.playing:
		return
	# 트리 밖에서 play() 를 부르면 엔진이 거절한다. 위 add_child 주석 참조.
	if not _music.is_inside_tree():
		return
	_music_started_at = float(Time.get_ticks_msec()) / 1000.0
	_music_tries += 1
	_music.play()
	print("BGM   play() %d회 → playing=%s  경로=%d  볼륨=%.0fdB  버스=%s" % [
		_music_tries, _music.playing, _music.playback_type, _music.volume_db, _music.bus])


## 배경음악이 왜 안 울리는지 한 줄로 말한다.
##
## 소리 문제는 화면에 아무 흔적을 안 남긴다. 파일을 못 찾은 것인지, 재생기가
## 안 만들어진 것인지, 브라우저가 막은 것인지가 전부 다른 문제인데 증상은
## 똑같이 "조용함" 하나다. 실패했을 때만 타이틀에 띄운다.
static func music_playing() -> bool:
	return _music != null and is_instance_valid(_music) and _music.playing


static func diagnose() -> String:
	if _music_name == "":
		return "음원 요청 없음"
	if _music == null or not is_instance_valid(_music):
		return "음원 파일을 불러오지 못했습니다 (assets/music)"
	if not enabled:
		return "소리가 꺼져 있습니다"
	if not audio_open():
		return "브라우저 잠금 (조작 대기)"
	if not _music.is_inside_tree():
		return "재생기가 화면 트리에 없습니다"
	if not _music.playing:
		var st := _music.stream
		return "재생기 정지 (%s · %.0f초 · 경로 %d · 시도 %d회)" % [
			st.get_class() if st != null else "스트림 없음",
			st.get_length() if st != null else 0.0,
			_music.playback_type, _music_tries]
	return "재생 중 · %.0f초 · %+.0fdB" % [
		_music.get_playback_position(), _music.volume_db]


## 곡이 끝나면 다시 튼다.
##
## ── 왜 finished 를 play 에 그냥 잇지 않는가 ──────────────────────────
## 재생이 실패하는 환경에서는 finished 가 즉시 날아온다. 그걸 바로 play 에
## 이어 두면 매 프레임 처음부터 다시 트는 상태가 되고, 결과는 완전한 무음이다.
## 소리가 안 나는 것과 구별도 안 된다. 방금 튼 곡이면 무시한다.
static func _on_music_finished() -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - _music_started_at < 1.0:
		return
	resume_music()


## 배경음악을 튼다. 같은 곡이 이미 돌고 있으면 아무것도 안 한다 -
## 화면이 바뀔 때마다 처음부터 다시 시작하면 음악이 계속 끊긴다.
## 지금 돌고 있는 곡 이름. 없으면 빈 문자열.
##
## 스토리 화면이 자기 곡을 틀기 전에 이 값을 적어 두고, 나갈 때 되돌린다.
static func music_name() -> String:
	return _music_name


func play_music(name: String) -> void:
	if _music_name == name and _music != null and is_instance_valid(_music):
		if not enabled:
			_music.stop()
		else:
			resume_music()
		return

	# ── 왜 wav 를 먼저 찾는가 ────────────────────────────────────────────
	# 효과음은 웹에서 멀쩡한데 배경음악만 안 나오는 상태가 오래 갔다. 파일도
	# 경로도 버스도 볼륨도 정상이었고, 브라우저 잠금도 이미 처리한 뒤였다.
	#
	# 원인은 **재생 경로가 둘**이라는 것이었다. Godot 은 소리를 자체 믹서로
	# 흘리거나(Stream), Web Audio 버퍼 하나로 통째로 올려 재생한다(Sample).
	# 어느 쪽을 쓸지는 프로젝트 설정이 정하는데, 실측하면 이렇다.
	#
	#     audio/general/default_playback_type      = 0 (Stream)
	#     audio/general/default_playback_type.web  = 1 (Sample)   ← 웹만 다르다
	#
	# 즉 웹에서는 **모든 소리가 Sample 로 나간다.** 효과음은 원래 wav 라
	# 그대로 버퍼가 되니까 멀쩡했고, 74초짜리 스트리밍 음원(mp3·ogg)만
	# 그 경로에서 소리 없이 죽었다. 데스크톱은 Stream 이라 셋 다 멀쩡했고,
	# 그래서 계측할 때마다 "정상" 이 찍혔다.
	#
	# 답은 음악도 효과음과 **같은 종류의 자원**으로 만드는 것이다. 74초를
	# 통으로 올리면 6.5MB 지만 임포터가 QOA 로 눌러 1.3MB 가 된다.
	# ogg·mp3 는 폴백으로 남긴다 - 데스크톱에서는 어느 쪽이든 울린다.
	# ── 진단 출력 ────────────────────────────────────────────────────────
	# 브라우저 콘솔(F12)에 그대로 찍힌다. 화면 라벨로는 어느 단계에서 죽었는지가
	# 한 줄로만 보이는데, 여기서는 경로·존재·로드 결과가 순서대로 나온다.
	print("BGM: ", name)
	var stream: AudioStream = null
	for ext in [".wav", ".ogg", ".mp3"]:
		var path: String = "res://assets/music/%s%s" % [name, ext]
		print("BGM   ", path, " exists=", ResourceLoader.exists(path))
		if not ResourceLoader.exists(path):
			continue
		var res = load(path)
		print("BGM   load -> ", res)
		if res is AudioStream:
			stream = res
			break
	if stream == null:
		print("BGM   음원을 못 찾았다")
		return

	# 트리 밖에서 부르면 get_tree() 가 null 이라 재생기를 붙일 곳이 없다.
	# 예전에 여기서 조용히 죽어 "음악만 안 나오는" 상태가 됐다. 한 프레임 미룬다.
	if not is_inside_tree():
		call_deferred("play_music", name)
		return

	stop_music()
	_music = AudioStreamPlayer.new()
	# 타이틀 테마는 반복 재생한다. 74초짜리라 한 번 돌면 정적이 된다.
	#
	# 스트림의 loop 플래그만 믿지 않는다. 임포트 설정(.import 의 loop)이 진짜
	# 주인이라 파일을 교체하면 false 로 되돌아가고, 런타임에서 덮어써도 이미
	# 만들어진 재생 인스턴스에는 안 먹는다. 실제로 그렇게 한 번 돌고 끝났다.
	# 그래서 끝나면 다시 트는 연결도 같이 건다 (_on_music_finished).
	if stream is AudioStreamWAV:
		# wav 임포터는 .import 의 edit/loop_mode 를 기본값으로 되돌려 놓는다.
		# 파일을 교체할 때마다 다시 꺼지므로 여기서 직접 건다.
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * float(w.mix_rate))
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_music.stream = stream
	# 음악은 효과음보다 확실히 낮게 깔린다. 같은 볼륨이면 타격감이 묻힌다.
	_music.volume_db = volume_db - 8.0
	# ── 재생 경로 ────────────────────────────────────────────────────────
	# 실측하면 웹만 기본값이 다르다.
	#   audio/general/default_playback_type     = 0 (Stream)
	#   audio/general/default_playback_type.web = 1 (Sample)
	#
	# 한 번 STREAM 으로 못 박았다가 오히려 소리가 통째로 죽었다. 화면 진단이
	# "재생기 정지 (AudioStreamWAV · 경로 1 · 시도 4회)" 를 찍어서 잡았다.
	# 웹에서 실제로 우는 길은 Sample 쪽이다 - 효과음이 나오는 이유가 그거고,
	# 음악만 굳이 STREAM 으로 옮기면서 그 길에서 빼내 버린 것이었다.
	#
	# 그래서 **아무것도 정하지 않는다.** 기본값(0)은 플랫폼이 고르라는 뜻이고,
	# 웹은 Sample, 데스크톱은 Stream 을 고른다. 음원이 AudioStreamWAV 라
	# 양쪽 다 성립한다 - mp3·ogg 였을 때 Sample 에서 죽은 게 처음 원인이었다.
	if not stream.can_be_sampled():
		# 그래도 못 샘플링하는 음원이면 믹서로 보낼 수밖에 없다.
		_music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	# ── 트리에 붙이는 것을 반드시 미룬다 ────────────────────────────────
	# 화면이 사라져도 음악은 살아 있어야 하므로 루트에 붙인다. 그런데 그냥
	# add_child 를 부르면 실패한다.
	#
	#   ERROR: Parent node is busy setting up children, `add_child()` failed.
	#   ERROR: Playback can only happen when a node is inside the scene tree
	#
	# play_music 은 TitleScreen.setup() 에서 불리고, 그 setup 은 Game._swap() 의
	# add_child(화면) **안에서** 실행된다. 그 순간 루트는 자식을 세팅하는 중이라
	# 새 자식을 거절한다. 재생기는 만들어지는데 트리에 못 들어가고, 그래서 play()
	# 가 영원히 실패한다. 화면에는 "재생기 정지" 로만 보인다.
	#
	# 이게 배경음악이 웹에서 안 나온 진짜 원인이었다. 계측이 매번 "정상" 을
	# 찍은 것은 프로브가 프레임을 한 번 돌린 뒤에 타이틀을 붙여서 루트가
	# 한가했기 때문이다. 부팅 경로를 그대로 재현하지 못한 것이다.
	get_tree().root.add_child.call_deferred(_music)
	_music.finished.connect(_on_music_finished)
	_music_name = name
	_music_tries = 0
	# 붙는 것이 미뤄졌으므로 재생도 미룬다. 트리에 실제로 들어간 순간 한 번만
	# 시도한다. 그때 아직 조작 전이면 resume_music 이 알아서 안 튼다.
	_music.tree_entered.connect(func(): resume_music(), CONNECT_ONE_SHOT)


func stop_music() -> void:
	if _music != null and is_instance_valid(_music):
		_music.stop()
		_music.queue_free()
	_music = null
	_music_name = ""
	_music_started_at = 0.0
	_music_tries = 0


## 이름 하나로 낸다. 없는 이름이면 조용히 무시한다 -
## 소리 때문에 게임이 멈추는 일은 없어야 한다.
## dedupe 를 따로 받는다. 기본값(0.045초)은 "같은 소리가 한 틱에 여섯 번
## 겹치는 것" 을 막으려는 값인데, 타자기 소리처럼 **원래 촘촘하게 이어져야
## 하는** 소리에는 그 방어가 오히려 소리를 지운다.
func play(name: String, pitch: float = 1.0, dedupe: float = -1.0) -> void:
	if not enabled or _players.is_empty():
		return
	var gap: float = DEDUPE if dedupe < 0.0 else dedupe
	if _clock - float(_last_at.get(name, -99.0)) < gap:
		return
	var stream := _stream_for(name)
	if stream == null:
		return
	_last_at[name] = _clock

	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db + SFX_TRIM
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
