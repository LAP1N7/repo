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


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_advance()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		_advance()


func _advance() -> void:
	index += 1
	if index >= beats.size():
		done.emit()
		return
	_show(index)


func _show(i: int) -> void:
	var b: Dictionary = beats[i]
	_lbl_name.text = String(b.get("speaker", ""))
	_lbl_text.text = String(b.get("text", ""))

	var art := String(b.get("art", ""))
	(_art as _ArtSlot).art_id = art
	_art.visible = art != ""
	_art.queue_redraw()

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

	func _draw() -> void:
		if art_id == "":
			return
		var tex := UiKit.art(["story"], art_id)
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
			return
		# 아직 안 들어온 배경. 자리만 잡아 둔다.
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.22, 0.23, 0.26))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.42, 0.44, 0.50), false, 1.0)
		draw_string(UiKit.font(12), Vector2(16, size.y - 16),
			"[배경 자리] %s" % art_id, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.6, 0.62, 0.7))


## 대사판. 카드·튜토리얼과 같은 사선 어법.
class _Panel extends Control:
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
		draw_polyline(line, UiKit.ACCENT, 1.8, true)


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
func _tick_log(delta: float) -> void:
	_log_t += delta
	# 처음 열 줄은 0.28초에 한 줄. 그 뒤로는 줄마다 빨라진다.
	var speed: float = 0.28 if _log_n < 10 else maxf(0.02, 0.28 - float(_log_n - 10) * 0.018)
	while _log_n < Story.LOG_LINES.size() and _log_t > speed:
		_log_t -= speed
		_log_n += 1
		_log.text = "
".join(Story.LOG_LINES.slice(0, _log_n))
	# 넘치면 위로 밀어 마지막 줄이 항상 보이게 한다.
	var over: float = maxf(0.0, float(_log_n) * 17.0 - 356.0)
	_log.position.y = 8.0 - over


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
