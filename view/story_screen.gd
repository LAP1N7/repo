class_name StoryScreen
extends Control

## 스토리 재생기. 장면을 하나씩 보여 주고 끝나면 done 을 쏜다.
##
## ── 왜 별도 화면인가 ─────────────────────────────────────────────────────
## 튜토리얼 말풍선은 게임 화면 **위에** 얹힌다. 지금 눌러야 할 곳을 가리켜야
## 하므로 그 아래가 보여야 하기 때문이다.
##
## 스토리는 반대다. 게임 화면을 **덮어야** 한다. 여기서 하는 이야기는 "지금 이
## 화면이 사실은 무엇인가" 이고, 그러려면 게임 화면이 잠깐 사라져야 무게가 산다.
##
## ── 아트가 없어도 진행된다 ───────────────────────────────────────────────
## art 가 지정됐는데 파일이 없으면 회색 네모를 놓는다. 배경이 나중에 들어와도
## 대본과 연출을 먼저 완성해 두려는 것이다. 이 프로젝트는 계속 그렇게 해 왔다.

signal done()

const PAD := 64.0

var beats: Array = []
var index: int = 0

var _art: Control
var _bubble: Control
var _lbl_name: Label
var _lbl_text: Label
var _lbl_hint: Label
var _fx: Control
var _log: Label
var _log_box: Control
var _log_t: float = 0.0
var _log_n: int = 0
var _t: float = 0.0
var _shake: float = 0.0


func setup(p_beats: Array) -> void:
	beats = p_beats
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_sfx = Sfx.new()
	add_child(_sfx)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.05)
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# 배경 아트 자리. 화면 위쪽 3분의 2를 쓴다.
	_art = _ArtSlot.new()
	_art.position = Vector2(PAD, 56)
	_art.size = Vector2(1280 - PAD * 2, 400)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	# 로그 화면. fx == "log" 인 장면에서만 보인다.
	# 로그는 줄이 서른 줄 가까이 되므로 반드시 잘라야 한다. Label 은 넘치면
	# 그냥 아래로 자라서 대사판을 뚫고 나간다 - 실제로 그렇게 겹쳤다.
	var log_box := _Holo.new()
	log_box.position = Vector2(PAD + 16, 70)
	log_box.size = Vector2(1280 - PAD * 2 - 32, 380)
	log_box.clip_contents = true
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(log_box)
	# 파란 단색. 시설 기록은 사람이 쓴 글이 아니라 기계가 남긴 것이므로 색이
	# 하나뿐이어야 한다. 흰색이면 그냥 자막처럼 보인다.
	_log = UiKit.label(log_box, Vector2(12, 8), Vector2(1280 - PAD * 2 - 56, 1400),
		"", 12, Color(0.55, 0.88, 1.0))
	log_box.visible = false
	_log_box = log_box

	_fx = _Glitch.new()
	_fx.size = Vector2(1280, 720)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)

	# ── 화자 초상 ────────────────────────────────────────────────────────
	# 미연시 어법이다. 목소리만 있던 존재가 화면에 서 있으면 같은 대사가 다르게
	# 읽힌다. 대사판보다 **먼저** 붙여 판이 초상 위에 얹히게 한다 - 인물이
	# 판 뒤에서 올라오는 것처럼 보여야 자연스럽다.
	#
	# 켜고 끄는 것은 대본이 정한다. data/story.json 의 각 대사에 "portrait" 를
	# 적으면 그 그림이 뜨고, 안 적으면 안 뜬다. 연출을 코드가 아니라 대본에서
	# 만지도록 두는 편이 훨씬 빠르다.
	_portrait = _Portrait.new()
	# ── 궁극기 컷인과 같은 어법 ──────────────────────────────────────────
	# 얼굴만 크게 잡으면 누가 말하는지는 알아도 **어떤 인물인지**가 안 남는다.
	# 컷인이 반신을 세로로 길게 보여 주는 것과 같은 이유로, 여기서도 인물을
	# 통째로 세운다. 아래는 대사판이 가리므로 잘려도 좋다.
	_portrait.position = Vector2(PAD + 4, 74)
	_portrait.size = Vector2(430, 560)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.visible = false
	add_child(_portrait)

	# 대사판. 튜토리얼 말풍선과 같은 사선 어법이다.
	_bubble = _Panel.new()
	_bubble.position = Vector2(PAD, 484)
	_bubble.size = Vector2(1280 - PAD * 2, 150)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)

	_lbl_name = UiKit.label(_bubble, Vector2(24, 14), Vector2(400, 24), "", 15, UiKit.ACCENT)
	_lbl_text = UiKit.label(_bubble, Vector2(24, 44), Vector2(1280 - PAD * 2 - 48, 90),
		"", 17, UiKit.TEXT, true)
	_lbl_hint = UiKit.label(self, Vector2(PAD, 646), Vector2(1280 - PAD * 2, 22),
		UiText.t("story.hint", "아무 곳이나 눌러 계속"), 12, UiKit.FAINT)
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	UiKit.frame(self, UiKit.ACCENT)
	_show(0)


## 화면이 열린 시각. 갓 열린 창은 잠시 입력을 안 받는다.
##
## ── 왜 필요한가 ──────────────────────────────────────────────────────────
## 보상 화면에서 카드를 누르면 그 클릭 이벤트가 아직 전파 중인 상태에서 이
## 화면이 트리에 붙는다. 그러면 **같은 클릭 하나가** 보상을 고르고 첫 대사까지
## 넘겨 버린다.
##
## 대사가 여러 줄인 대목은 한 줄만 건너뛰니 티가 안 났다. 그런데 pre_2 처럼
## 대사가 **한 줄뿐인** 대목은 그 한 번에 통째로 끝나서, 화면이 아예 안 뜬
## 것처럼 보였다. 실제로 "1스테이지 전 대사는 나오는데 2스테이지 것은 안
## 나온다" 로 보고됐다.
##
## 대본을 늘려서 가릴 문제가 아니다. 대사가 한 줄이어도 읽을 시간은 있어야 한다.
var _portrait: Control

## MIRA 는 시설의 AI 다. 이름을 한 곳에만 적어 둔다.
const MIRA_NAME := "MIRA"
const COL_MIRA := Color(0.96, 0.97, 1.0)
## 대사판 테두리에 쓰는 MIRA 색. 이름은 흰색이지만 판은 하늘색이다 -
## 흰 테두리는 그냥 밝은 선으로 보여서 "누구" 를 말하지 못한다.
const COL_MIRA_EDGE := Color(0.45, 0.80, 1.0)
const COL_HUMAN := Color(1.0, 0.78, 0.35)
const COL_NARRATION := Color(0.58, 0.62, 0.70)

## 지금 깔려 있는 배경. 대사가 배경을 안 적으면 이 값이 이어진다.
## 지금 대사의 전체 글월과, 어디까지 찍었는지.
##
## 글자 수를 실수로 들고 있는 이유는 속도를 초당 글자 수로 주기 때문이다.
## 정수로 세면 프레임률에 따라 박자가 흔들린다.
var _full: String = ""
var _typed: float = 0.0

## 초당 몇 글자. 소리와 같이 나므로 너무 빠르면 잡음이 된다.
const TYPE_CPS: float = 34.0
## 몇 글자마다 소리를 낼지. 매 글자면 소리가 뭉개진다.
const TYPE_SFX_EVERY: int = 2

var _bg_id: String = ""
var _sfx: Sfx

var _opened_ms: int = 0

## 이 시간 안에 들어온 입력은 앞 화면에서 새어 나온 것으로 본다.
const INPUT_GUARD_MS: int = 250


func _ready() -> void:
	_opened_ms = Time.get_ticks_msec()


func _accepts_input() -> bool:
	return Time.get_ticks_msec() - _opened_ms >= INPUT_GUARD_MS


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and _accepts_input():
		_advance()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and _accepts_input():
		_advance()


func _advance() -> void:
	# ── 로그가 흐르는 중이면 먼저 끝까지 뿌린다 ──────────────────────────
	# 예전에는 아무 때나 누르면 다음 대사로 넘어갔다. 그래서 서른 줄짜리
	# 기록이 두 줄쯤 나왔을 때 실수로 눌러 통째로 날아갔고, 그게 이 이야기의
	# 정체가 밝혀지는 유일한 장면이다.
	#
	# 한 번은 "다 보여 줘", 두 번째가 "넘어가" 다. 건너뛸 수는 있되 모르고
	# 지나칠 수는 없게 한다.
	if _log_box != null and _log_box.visible and _log_n < Story.LOG_LINES.size():
		_log_n = Story.LOG_LINES.size()
		_log.text = "
".join(Story.LOG_LINES)
		return
	# 찍히는 중이면 먼저 다 찍는다. 같은 규칙이다 - 건너뛸 수는 있되 모르고
	# 지나칠 수는 없게 한다.
	if _typed < float(_full.length()):
		_typed = float(_full.length())
		_lbl_text.text = _full
		return
	index += 1
	if index >= beats.size():
		done.emit()
		return
	_show(index)


func _show(i: int) -> void:
	var b: Dictionary = beats[i]
	_lbl_name.text = String(b.get("speaker", ""))
	# ── 한 글자씩 찍는다 ─────────────────────────────────────────────────
	# 대사가 통째로 튀어나오면 읽는 속도를 화면이 정해 주지 않는다. 한 글자씩
	# 찍히면 눈이 글을 따라가고, 그 사이에 소리가 붙으면 "누가 지금 말하고
	# 있다" 가 된다. 시설 AI 가 화자인 이야기에 특히 맞는 어법이다.
	_full = String(b.get("text", ""))
	_typed = 0.0
	_lbl_text.text = ""

	# ── 화자에 따라 이름 색을 가른다 ─────────────────────────────────────
	# MIRA 는 시설의 목소리다. 사람이 아니므로 감정 색을 주지 않는다 - 흰색.
	# 대원과 그 밖의 사람은 호박색. 색 하나로 "지금 기계가 말하나 사람이
	# 말하나" 가 읽히면, 이야기가 뒤집히는 대목에서 그 차이가 무기가 된다.
	# ── 누가 말하는지를 테두리로도 말한다 ────────────────────────────────
	# 이름 색만으로는 대사판을 볼 때 시선이 이름줄에 한 번 갔다 와야 한다.
	# 판 자체가 색을 띠면 글을 읽기 전에 화자를 안다.
	#
	#   MIRA      하늘색 - 기계의 목소리
	#   대원       호박색 - 사람
	#   나레이션   회색   - 아무도 말하지 않는다
	var speaker := String(b.get("speaker", ""))
	var voice: Color = COL_NARRATION
	if speaker == MIRA_NAME:
		voice = COL_MIRA_EDGE
	elif speaker != "":
		voice = COL_HUMAN
	_lbl_name.add_theme_color_override("font_color", voice)
	(_bubble as _Panel).tint = voice
	_bubble.queue_redraw()

	# 화자 초상. 대본이 "portrait" 를 적은 대사에서만 뜬다.
	var portrait := String(b.get("portrait", ""))
	_portrait.visible = portrait != ""
	if portrait != "":
		(_portrait as _Portrait).art_id = portrait
		_portrait.queue_redraw()

	# ── 배경 ─────────────────────────────────────────────────────────────
	# 대사마다 따로 지정한다. 안 적으면 **앞 장면의 배경이 그대로 이어진다** -
	# 한 장소에서 대사가 다섯 줄 오갈 때마다 같은 파일 이름을 다섯 번 적는 것은
	# 대본이 할 일이 아니다. 장소를 바꾸고 싶을 때만 적는다.
	#
	# 배경을 걷어내고 싶으면 "none" 이라고 적는다. 빈 문자열은 "그대로" 라서
	# 끄는 뜻으로 못 쓴다.
	var art := String(b.get("art", _bg_id))
	if art == "none":
		art = ""
	_bg_id = art
	(_art as _ArtSlot).art_id = art
	_art.visible = art != ""
	_art.queue_redraw()

	# ── 음악 ─────────────────────────────────────────────────────────────
	# 같은 어법이다. 적은 대사에서 곡이 바뀌고, 안 적으면 그대로 이어진다.
	# (Sfx.play_music 은 같은 곡이면 아무것도 안 한다 - 다시 시작하지 않는다)
	var bgm := String(b.get("music", ""))
	if bgm != "" and _sfx != null:
		_sfx.play_music(bgm)

	var fx := String(b.get("fx", ""))
	_log_box.visible = fx == "log"
	if fx == "log":
		# 한 번에 다 뿌리지 않는다. 시설 기록이 차곡차곡 쌓이다가 어느 지점부터
		# 눈이 못 따라갈 속도로 넘어가는 것이 이 장면의 전부다. 그 가속을
		# 글로 설명하지 않고 실제로 그렇게 흐르게 한다.
		_log_t = 0.0
		_log_n = 0
		_log.text = ""
	(_fx as _Glitch).mode = fx
	(_fx as _Glitch).t0 = _t
	_fx.queue_redraw()

	# 몰아보기의 구간 표지. 대사가 아니라 목차라 색과 크기를 달리한다.
	var marker := bool(b.get("marker", false))
	_lbl_text.add_theme_color_override("font_color",
		UiKit.ACCENT if marker else UiKit.TEXT)
	_lbl_text.add_theme_font_size_override("font_size", 22 if marker else 17)

	# collapse 는 판을 지운다. "모든 표시가 사라진다" 를 글로 적는 대신 실제로
	# 사라지게 한다 - 이 이야기의 마지막 장면이 그걸 요구한다.
	_bubble.modulate.a = 0.25 if fx == "collapse" else 1.0
	if fx == "glitch" or fx == "collapse":
		_shake = 1.0


func _process(delta: float) -> void:
	_t += delta
	_tick_type(delta)

	if _log_box != null and _log_box.visible:
		_tick_log(delta)
		_log_box.queue_redraw()
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 2.2)
		position = Vector2(sin(_t * 90.0) * 6.0 * _shake, cos(_t * 71.0) * 4.0 * _shake)
	else:
		position = Vector2.ZERO
	if (_fx as _Glitch).mode != "":
		_fx.queue_redraw()


# ── 조각들 ───────────────────────────────────────────────────────────────

## 배경 아트 자리. 파일이 없으면 회색 네모와 자리 이름만 놓는다.
class _ArtSlot extends Control:
	var art_id: String = ""
	var _img: Control
	var _shown: String = ""

	func _draw() -> void:
		if art_id == "":
			return
		var tex := UiKit.art(["story"], art_id)
		if tex != null:
			# 그림은 노드로 붙인다. draw_texture_rect 는 이 프로젝트에서
			# 흰 사각형이 된다. (UiKit.image 주석 참조)
			if _shown != art_id:
				_shown = art_id
				if _img != null:
					_img.queue_free()
				_img = UiKit.image(self, Rect2(Vector2.ZERO, size), tex, "cover")
			return
		if _img != null:
			_img.queue_free()
			_img = null
			_shown = ""
		# 아직 안 들어온 배경. 자리만 잡아 둔다.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.22, 0.23, 0.26))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.42, 0.44, 0.50), false, 1.0)
		draw_string(UiKit.font(12), Vector2(16, size.y - 16),
			"[배경 자리] %s" % art_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.6, 0.62, 0.7))


## 대사판. 카드·튜토리얼과 같은 사선 어법.
class _Panel extends Control:
	var tint: Color = UiKit.ACCENT

	func _draw() -> void:
		var s := size
		var cut := 20.0
		var shape := PackedVector2Array([
			Vector2(cut, 0), Vector2(s.x, 0), Vector2(s.x, s.y - cut),
			Vector2(s.x - cut, s.y), Vector2(0, s.y), Vector2(0, cut),
		])
		draw_colored_polygon(shape, Color(0.06, 0.07, 0.10, 0.95))
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		draw_polyline(line, tint, 1.8, true)


## 화면 깨짐·동기화 표시.
##
## 전부 시간 함수로 그린다. 난수를 쓰면 볼 때마다 달라져서 "버그인가?" 하는
## 첫인상이 흐려진다. 같은 자리에서 같은 모양으로 깨져야 의도된 것으로 읽힌다.
class _Glitch extends Control:
	var mode: String = ""
	var t0: float = 0.0

	func _draw() -> void:
		match mode:
			"glitch", "collapse":
				# ── 찢어진 띠 ────────────────────────────────────────────
				# 얇은 선을 겹치는 것만으로는 "화면에 효과가 얹혔다" 로만 보인다.
				# 굵은 띠를 좌우로 크게 어긋내면 **화면 자체가 찢어진** 것처럼
				# 읽힌다. 이 장면은 플레이어가 잠깐 버그로 착각해야 하므로
				# 효과처럼 예쁘면 안 된다.
				var ms := float(Time.get_ticks_msec())
				for i in 9:
					var y := fmod(float(i) * 151.7 + ms * 0.11, 760.0) - 40.0
					var h := 8.0 + float(i % 5) * 14.0
					var off := sin(float(i) * 1.9 + ms * 0.006) * 90.0
					draw_rect(Rect2(off, y, 1280, h), Color(0.03, 0.05, 0.09, 0.85))
					draw_rect(Rect2(off - 6, y, 1280, 2), Color(0.45, 0.9, 1.0, 0.55))
					draw_rect(Rect2(off + 6, y + h - 2, 1280, 2), Color(1.0, 0.4, 0.5, 0.35))
				# 색 분리. 빨강과 청록을 반대로 밀면 신호가 흐트러진 것처럼 보인다.
				draw_rect(Rect2(-5, 0, 1280, 720), Color(1.0, 0.2, 0.3, 0.05))
				draw_rect(Rect2(5, 0, 1280, 720), Color(0.2, 1.0, 0.9, 0.05))
				# 가로 노이즈 띠 하나가 화면을 훑는다.
				var sweep := fmod(ms * 0.35, 900.0) - 90.0
				draw_rect(Rect2(0, sweep, 1280, 26), Color(0.8, 0.95, 1.0, 0.09))
			"sync":
				# ── 14% 에서 멈춘다 ──────────────────────────────────────
				# 진행 막대는 보통 "곧 끝난다" 를 말하는 물건이다. 14% 에서
				# 멎어 있으면 그 기대가 어긋나고, 그 어긋남이 이 장면의 전부다.
				# 그래서 막대를 크게 놓고 화면을 어둡게 덮어 여기만 보게 한다.
				draw_rect(Rect2(0, 0, 1280, 720), Color(0.01, 0.02, 0.04, 0.82))
				var pct := 14
				var w := 720.0
				var x := (1280.0 - w) * 0.5
				var beat := 0.55 + 0.45 * absf(sin(float(Time.get_ticks_msec()) * 0.004))
				draw_rect(Rect2(x, 352, w, 16), Color(0.10, 0.12, 0.16))
				draw_rect(Rect2(x, 352, w, 16), Color(0.35, 0.75, 1.0, 0.5), false, 1.0)
				draw_rect(Rect2(x, 352, w * float(pct) / 100.0, 16),
					Color(0.45, 0.85, 1.0, beat))
				# 눈금. 100% 가 어디인지 보여야 14% 가 얼마나 모자란지 읽힌다.
				for i in 11:
					var tx := x + w * float(i) / 10.0
					draw_line(Vector2(tx, 372), Vector2(tx, 378),
						Color(0.35, 0.75, 1.0, 0.35), 1.0)
				draw_string(UiKit.font_role("large"), Vector2(x, 336),
					"MEMORY SYNCHRONIZATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
					Color(0.55, 0.88, 1.0))
				draw_string(UiKit.font_role("large"), Vector2(x + w - 70, 336),
					"%d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
					Color(0.45, 0.85, 1.0, beat))
				draw_string(UiKit.font(11), Vector2(x, 398),
					"... 동기화가 진행되지 않습니다", HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
					Color(0.5, 0.6, 0.7))


## 로그가 흐르는 속도.
##
## 앞부분(평범한 시설 기록)은 한 줄씩 천천히 올라가고, 뒤로 갈수록 가속한다.
## 그 가속이 "무언가 일어났다" 를 말한다 - 글로 설명하지 않는다.
## ── 로그는 한 줄씩, 천천히 ───────────────────────────────────────────────
## 예전에는 뒤로 갈수록 빨라져 마지막 열 줄이 한 프레임에 쏟아졌다. "가속" 은
## 의도였지만 결과는 그냥 안 읽히는 화면이었다.
##
## 아날로그 호러의 무서움은 속도가 아니라 **속도가 일정하다는 것**에서 온다.
## 기계가 사람 사정과 무관하게 제 박자로 계속 뱉는다. 그래서 한 줄에 0.34초로
## 고정하고, 종이가 밀려 올라가듯 화면도 그만큼씩만 흐르게 한다.
const LOG_LINE_SEC: float = 0.34
const LOG_LINE_H: float = 17.0

## 대사를 한 글자씩 찍는다. 다 찍으면 아무것도 안 한다.
func _tick_type(delta: float) -> void:
	if _lbl_text == null or _typed >= float(_full.length()):
		return
	var before := int(_typed)
	_typed = minf(_typed + delta * TYPE_CPS, float(_full.length()))
	var now := int(_typed)
	if now == before:
		return
	_lbl_text.text = _full.substr(0, now)
	# 공백에서는 소리를 내지 않는다. 띄어쓰기마다 딸깍하면 말이 아니라
	# 기계 소음으로 들린다.
	if now % TYPE_SFX_EVERY == 0 and _full[now - 1].strip_edges() != "":
		# dedupe 를 꺼야 한다. 기본 0.045초는 초당 34글자를 통째로 지운다.
		_sfx.play("typing", 0.94 + float(now % 5) * 0.03, 0.0)


func _tick_log(delta: float) -> void:
	if _log_n < Story.LOG_LINES.size():
		_log_t += delta
		while _log_n < Story.LOG_LINES.size() and _log_t > LOG_LINE_SEC:
			_log_t -= LOG_LINE_SEC
			_log_n += 1
			_log.text = "
".join(Story.LOG_LINES.slice(0, _log_n))

	# ── 스크롤은 따로, 부드럽게 ──────────────────────────────────────────
	# 줄이 늘 때마다 위치를 툭 바꾸면 글이 한 칸씩 튄다. 목표 지점을 정해 두고
	# 매 프레임 그쪽으로 조금씩 다가가면 종이가 밀려 올라가는 것처럼 흐른다.
	var want: float = 8.0 - maxf(0.0, float(_log_n) * LOG_LINE_H - 348.0)
	_log.position.y = lerpf(_log.position.y, want, clampf(delta * 6.0, 0.0, 1.0))


## 파란 홀로그램 판. 스캔라인과 노이즈.
##
## 시설 로그는 화면이 아니라 **투영**이어야 한다. 판을 파랗게 깔고 가로선을
## 겹치면 그것만으로 "여기 띄워진 것" 이 된다. 노이즈는 고정 시드 LCG 로
## 만든다 - 볼 때마다 다르면 연출이 아니라 잡음으로 읽힌다.
class _Holo extends Control:
	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.12, 0.20, 0.92))
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.35, 0.75, 1.0, 0.55), false, 1.5)

		# 스캔라인. 3px 간격으로 한 줄씩 어둡게 깐다.
		var y := 0.0
		while y < s.y:
			draw_line(Vector2(0, y), Vector2(s.x, y), Color(0, 0, 0, 0.22), 1.0)
			y += 3.0

		# 흐르는 밝은 띠. 이게 있어야 정지 화면으로 안 보인다.
		var band := fmod(float(Time.get_ticks_msec()) * 0.09, s.y + 120.0) - 60.0
		draw_rect(Rect2(0, band, s.x, 40), Color(0.45, 0.85, 1.0, 0.06))

		# 노이즈. 고정 시드 LCG 라 매번 같은 자리에 낀다.
		var seed_v: int = 20260806
		for i in 90:
			seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
			var nx := float(seed_v % maxi(1, int(s.x)))
			seed_v = (seed_v * 1103515245 + 12345) & 0x7FFFFFFF
			var ny := float(seed_v % maxi(1, int(s.y)))
			draw_rect(Rect2(nx, ny, 2, 1), Color(0.6, 0.9, 1.0, 0.16))


## 화자 초상. 대사판 위로 반신이 올라온다.
##
## 아래를 잘라 낸다 - 미연시가 인물을 무릎에서 자르는 이유와 같다. 발끝까지
## 보이면 인물이 작아지고, 얼굴이 화면에서 차지하는 비율이 그만큼 줄어든다.
##
## 그림은 TextureRect 자식으로 붙인다. _draw() 안의 draw_texture_rect 는 이
## 프로젝트에서 텍스처를 흰 사각형으로 칠한다(SD 얼굴·지형 배경에서 두 번 겪었다).
class _Portrait extends Control:
	var art_id: String = ""
	var _tr: TextureRect

	func _ready() -> void:
		clip_contents = true
		_tr = TextureRect.new()
		# 이 한 줄이 빠지면 TextureRect 의 최소 크기가 텍스처 크기라, size 를
		# 아무리 작게 줘도 원본 크기로 되돌아간다. 896x1182 짜리 그림이
		# 360x420 칸 안에서 원본 배율로 그려져 **얼굴만 꽉 차** 있었다.
		# 편성 얼굴 타일에서 이미 한 번 겪은 함정이다.
		_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_tr.stretch_mode = TextureRect.STRETCH_SCALE
		_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_tr)
		_apply()

	func _draw() -> void:
		_apply()

	func _apply() -> void:
		if _tr == null:
			return
		var tex := UiKit.art(["standing", "portraits"], art_id) if art_id != "" else null
		_tr.texture = tex
		if tex == null:
			return
		# ── 인물을 통째로 세운다 ─────────────────────────────────────────
		# 가로·세로 중 **작은 쪽**에 맞춘다. 세로만 맞추면 가로로 넘쳐 좌우가
		# 잘리고, 그러면 활이나 무기처럼 옆으로 뻗은 것이 통째로 사라진다.
		# 인물이 누구인지는 실루엣이 말하는데 그 실루엣이 잘리면 의미가 없다.
		var ts := Vector2(tex.get_width(), tex.get_height())
		if ts.y <= 0.0 or ts.x <= 0.0:
			return
		var k: float = minf(size.x / ts.x, size.y / ts.y)
		_tr.size = ts * k
		# 가로는 가운데, 세로는 바닥에 세운다 - 발치가 대사판에 닿아야
		# 인물이 화면에 서 있는 것으로 읽힌다.
		_tr.position = Vector2((size.x - _tr.size.x) * 0.5, size.y - _tr.size.y)
