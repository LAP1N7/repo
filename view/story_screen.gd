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
	var log_box := Control.new()
	log_box.position = Vector2(PAD + 16, 70)
	log_box.size = Vector2(1280 - PAD * 2 - 32, 380)
	log_box.clip_contents = true
	log_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(log_box)
	_log = UiKit.label(log_box, Vector2.ZERO, Vector2(1280 - PAD * 2 - 32, 380),
		"", 12, Color(0.85, 0.92, 1.0))
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
		_log.text = "\n".join(Story.LOG_LINES)
	(_fx as _Glitch).mode = fx
	(_fx as _Glitch).t0 = _t
	_fx.queue_redraw()

	# collapse 는 판을 지운다. "모든 표시가 사라진다" 를 글로 적는 대신 실제로
	# 사라지게 한다 - 이 이야기의 마지막 장면이 그걸 요구한다.
	_bubble.modulate.a = 0.25 if fx == "collapse" else 1.0
	if fx == "glitch" or fx == "collapse":
		_shake = 1.0


func _process(delta: float) -> void:
	_t += delta
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
				for i in 14:
					var y := fmod(float(i) * 97.3 + Time.get_ticks_msec() * 0.06, 720.0)
					var h := 2.0 + float(i % 4) * 3.0
					var off := sin(float(i) * 2.7 + Time.get_ticks_msec() * 0.004) * 22.0
					draw_rect(Rect2(off, y, 1280, h), Color(0.55, 0.85, 1.0, 0.10))
				draw_rect(Rect2(0, 0, 1280, 720), Color(0.7, 0.9, 1.0, 0.04))
			"sync":
				var pct := 14
				var w := 520.0
				var x := (1280.0 - w) * 0.5
				draw_rect(Rect2(x, 330, w, 10), Color(0.16, 0.17, 0.21))
				draw_rect(Rect2(x, 330, w * float(pct) / 100.0, 10), UiKit.GOOD)
				draw_string(UiKit.font_role("large"), Vector2(x, 316),
					"MEMORY SYNCHRONIZATION  %d%%" % pct,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiKit.GOOD)
