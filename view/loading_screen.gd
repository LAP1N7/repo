class_name LoadingScreen
extends Control

## 화면 전환 사이에 끼는 로딩 연출.
##
## ── 실제로는 로딩할 게 없다 ─────────────────────────────────────────────
## 씬이 전부 코드로 만들어져서 전환은 즉시 끝난다. 그런데도 이 화면을 두는 이유는
## 두 가지다.
##
##   1. 세계관 - 화면은 "가공 전 시뮬레이션 레이어" 라는 설정이다. 판이 바뀔 때
##      신호가 흔들리는 연출이 그 설정을 매번 상기시킨다.
##   2. 정보 - 이 게임은 규칙이 많다. 슬롯 순서, 궁극기 1회제, 정체 판정 같은 것을
##      어디선가는 말해야 하는데, 화면마다 설명을 늘리면 UI 가 텍스트로 뒤덮인다.
##      전환 구간은 원래 비어 있는 시간이라 여기가 제자리다.
##
## ── 왜 건너뛰기를 열어 두는가 ──────────────────────────────────────────
## 없는 로딩을 기다리게 하는 건 그 자체로 무례하다. 아무 키나 클릭으로 즉시 넘어간다.

signal done()

const DATA_PATH := "res://data/tips.json"

## 자동으로 넘어가는 시간. 팁 한 줄을 읽기에 충분하되 지루하지 않은 길이.
const HOLD: float = 2.2

var _t: float = 0.0
var _tip: String = ""
var _is_dedication: bool = false
var _finished: bool = false

var _lbl_title: Label
var _lbl_tip: Label
var _lbl_hint: Label
var _bar: ColorRect


func setup(rng_seed: int = 0) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.05)
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_pick(rng_seed)

	_lbl_title = UiKit.label(self, Vector2(0, 250), Vector2(1280, 46),
		UiText.t("loading.head", "PROJECT RECLAIM"), 34, UiKit.ACCENT)
	_lbl_title.add_theme_font_override("font", UiKit.title_font())
	_lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 진행 막대. 실제 진행률이 아니라 시간에 비례한 연출이다.
	_bar = ColorRect.new()
	_bar.color = UiKit.ACCENT
	_bar.position = Vector2(340, 316)
	_bar.size = Vector2(0, 3)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)

	_lbl_tip = UiKit.label(self, Vector2(240, 370), Vector2(800, 80), _tip, 15,
		UiKit.MUTED if not _is_dedication else Color(0.72, 0.78, 0.95), true)
	_lbl_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_lbl_hint = UiKit.label(self, Vector2(0, 640), Vector2(1280, 20),
		UiText.t("loading.skip", "아무 곳이나 눌러 넘어간다"), 11, UiKit.FAINT)
	_lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## 팁을 고른다. 가끔 헌사가 대신 나온다.
##
## 헌사는 게임 설명이 아니라 세계관 조각이다. 흔해지면 무게가 사라지므로
## 확률을 낮게 잡는다. (data/tips.json 의 dedication_pct)
func _pick(rng_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else int(Time.get_ticks_usec())

	var tips: Array = []
	var deds: Array = []
	var pct := 12
	if FileAccess.file_exists(DATA_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			tips = parsed.get("tips", [])
			deds = parsed.get("dedications", [])
			pct = int(parsed.get("dedication_pct", 12))

	if not deds.is_empty() and rng.randi_range(1, 100) <= pct:
		_is_dedication = true
		_tip = String(deds[rng.randi_range(0, deds.size() - 1)])
		return
	if not tips.is_empty():
		_tip = "TIP.   " + String(tips[rng.randi_range(0, tips.size() - 1)])


func _process(delta: float) -> void:
	_t += delta
	_bar.size.x = clampf(_t / HOLD, 0.0, 1.0) * 600.0
	queue_redraw()
	if _t >= HOLD:
		_finish()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_finish()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	done.emit()


## 지직거리는 주사선. 신호가 불안정한 화면처럼 보이게 한다.
##
## 난수를 매 프레임 새로 뽑지 않고 시간으로 위치를 만든다. 그래야 프레임레이트가
## 흔들려도 같은 속도로 흐르고, 무엇보다 결정론을 안 깨서 캡처가 재현된다.
func _draw() -> void:
	var w := 1280.0
	var h := 720.0

	# 가로 주사선 - 전체에 얇게 깔린다.
	for i in 90:
		var y := float(i) * 8.0
		draw_rect(Rect2(0, y, w, 1), Color(1, 1, 1, 0.018))

	# 흐르는 밝은 띠 두 개. 속도를 다르게 줘서 규칙적으로 안 보이게 한다.
	for k in 2:
		var speed := 220.0 + float(k) * 130.0
		var y2 := fmod(_t * speed + float(k) * 300.0, h + 60.0) - 30.0
		draw_rect(Rect2(0, y2, w, 2 + k), Color(0.55, 0.75, 1.0, 0.07))

	# 순간적으로 어긋나는 블록. sin 두 개를 곱해 불규칙한 간격을 만든다.
	var g := sin(_t * 13.0) * sin(_t * 7.3)
	if g > 0.72:
		var by := fmod(_t * 900.0, h)
		var dx := (g - 0.72) * 120.0
		draw_rect(Rect2(dx, by, w, 14.0), Color(1.0, 0.4, 0.4, 0.10))
		draw_rect(Rect2(-dx, by + 6.0, w, 10.0), Color(0.4, 0.9, 1.0, 0.10))
