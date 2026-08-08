class_name CardNode
extends Control

## 규칙 카드 한 장. 발라트로식 손맛 담당.
##
## 호버하면 들리고 살짝 커지고 기울어진다. 가만히 있어도 아주 약하게 흔들린다.
## 애니메이션은 Tween 이 아니라 _process 의 지수 감쇠 보간으로 돌린다.
## Tween 을 쓰면 카드가 재배치될 때마다 이전 Tween 과 싸워서 튄다.

signal clicked(node: CardNode)

## 카드 한 장의 기준 크기.
##
## ── 카드를 그만두고 블록으로 ─────────────────────────────────────────────
## 152x196 세로 카드였다. 카드 어법(사선 프레임 · 일러스트 배너 · 호버로 들리고
## 기울어짐)은 손맛이 좋았지만, 이 게임에서 카드가 하는 일은 결국 **한 줄짜리
## 규칙을 보여 주는 것**이다. 세로로 긴 판의 절반은 늘 비어 있었고, 그 빈자리
## 때문에 화면마다 다섯 장을 놓을 데가 없어 배치가 계속 꼬였다.
##
## 가로로 눕힌 블록으로 바꾼다. 같은 폭에 다섯이 나란히 서고, 세로를 3분의 1만
## 쓰므로 아래에 다른 것을 놓을 자리가 생긴다. 정보는 오히려 늘었다 - 이름과
## 조건과 행동이 한 덩어리로 붙어 읽힌다.
##
##   [축색띠] AXIS        (비용)
##            이름
##            조건 → 행동
const W: float = 232.0
const H: float = 92.0

## 카드에서 일러스트 배너가 차지하는 세로 비율. ASSETS.md 의 카드 아트 규격과 맞물린다.
const BANNER_RATIO: float = 0.38

var card_id: String = ""
var index: int = -1

## 손패처럼 작게 그릴 때 쓴다.
var mini: bool = false

var base_pos: Vector2 = Vector2.ZERO
var base_rot: float = 0.0
var enabled: bool = true

## 합성 단계. 1 이면 원본. 화면이 레벨이 반영된 문장을 보여 줘야 한다 -
## 카드에는 "위력 100%" 라고 적혀 있는데 실제로는 140% 로 때리면 안 된다.
var level: int = 1

## 마지막으로 _draw() 를 돌렸을 때의 상태. 내용이 안 바뀌었으면 다시 안 그린다.
var _drawn_hover: bool = false
var _drawn_enabled: bool = true

## 미니 카드를 호버해서 원래 크기로 펼친 상태.
##
## ── 왜 scale 로 안 키우는가 ──────────────────────────────────────────────
## scale 만 1.39 배로 주면 그림은 커지지만 **레이아웃은 미니 그대로**다. 말줄임된
## 글자는 여전히 말줄임된 채로 크게 보일 뿐이고, 그러면 확대하는 의미가 없다.
## 노드 크기 자체를 원래 카드 크기로 바꿔서 전문이 실제로 다시 배치되게 한다.
var _expanded: bool = false

## 하단 안내 문구. "예산 부족" 같은 상태를 카드 위에 직접 띄운다.
var note: String = ""

var _hover: bool = false
var _lift: float = 0.0
var _scale: float = 1.0
var _tilt: float = 0.0
var _t: float = 0.0



func setup(p_card_id: String, p_index: int, p_mini: bool = false,
		_show_ban: bool = false, _ban_left: int = -1) -> void:
	card_id = p_card_id
	index = p_index
	mini = p_mini

	custom_minimum_size = card_size()
	size = card_size()
	pivot_offset = card_size() * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP

	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func(): _hover = false)
	gui_input.connect(_on_gui_input)


	# 살짝 다른 위상으로 흔들리게 해서 카드가 한 덩어리로 보이지 않게 한다.
	_t = float(p_index) * 0.7

	# _process 는 내용이 바뀔 때만 다시 그린다. 내용이 정해지는 건 여기이므로
	# 한 번은 명시적으로 요청해야 한다.
	queue_redraw()


## 지금 그려야 할 크기.
##
## 미니 카드는 0.72배로 줄여 두고, 마우스를 올리면 원래 크기로 펼친다.
## 원래 크기 카드(상점)는 마우스를 올리면 **원래보다 더 크게** 펼친다.
##
## ── 왜 상점 카드까지 키우는가 ────────────────────────────────────────
## 128x168 안에 조건과 행동을 각각 두 줄까지밖에 못 담아서, 긴 설명은
## "직전 틱에 아군이 적..." 처럼 잘렸다. 살 물건의 설명이 잘려 있으면
## 무엇을 사는지 모르는 채로 사게 된다. 펼치면 잘림이 사라진다.
## 미니 카드의 배율. 화면마다 카드가 하는 일이 달라서 크기도 달라야 한다.
## 상점은 스무 장을 훑는 자리라 작게, 편성은 이미 산 것을 꽂는 자리라 크게.
var mini_scale: float = 0.72


func card_size() -> Vector2:
	if mini:
		return Vector2(W, H) * (1.0 if _expanded else mini_scale)
	return Vector2(W, H) * (EXPAND if _expanded else 1.0)


## 원래 크기 카드를 펼칠 배율. 폭이 늘어나면 한 줄에 더 들어가고,
## 높이가 늘어나면 줄 수가 늘어난다. 둘 다 필요하다.
## 펼침 배율. 1.0 이면 크기를 안 바꾼다.
##
## 예전에는 1.62 로 레이아웃 박스를 키웠는데, 그러면 [제외] 버튼과 ULTIMATE
## 라벨이 원래 자리에서 밀려 프레임 밖으로 삐져나갔다. 안쪽 요소가 전부 고정
## 좌표라 박스만 늘리면 어긋난다.
##
## 지금은 크기를 그대로 두고 **위로 띄우고 앞으로 세운다.** 옆 카드에 가리지
## 않는 것이 목적이었으므로 그걸로 충분하고, 글자가 잘리는 문제도 없다.
const EXPAND: float = 1.0


## 지금 미니 레이아웃으로 그려야 하는가. 펼쳐졌으면 아니다.
func _is_mini() -> bool:
	return mini and not _expanded


func place(pos: Vector2, rot: float = 0.0) -> void:
	base_pos = pos
	base_rot = rot
	position = pos
	rotation = rot


func _on_gui_input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)


func _process(delta: float) -> void:
	_t += delta

	var want_hover := _hover and enabled

	# 마우스를 올리면 카드가 펼쳐진다. 손패의 미니든 상점의 원래 크기든,
	# 잘린 설명의 전문을 읽는 수단이 이것뿐이다.
	var want_expand := want_hover
	if want_expand != _expanded:
		_expanded = want_expand
		var sz := card_size()
		size = sz
		pivot_offset = sz * 0.5
		# 펼치면 [제외] 버튼도 같이 내려가야 한다. 안 옮기면 카드 한가운데에
		# 남아 본문을 가린다.
		queue_redraw()

	# [제외] 버튼은 매 프레임 현재 크기 기준으로 다시 놓는다. setup 에서 한 번만
	# 놓으면 트리에 들어가기 전 크기로 굳어 프레임 밖으로 삐져나간다.

	var target_lift: float = -34.0 if want_hover else 0.0
	# 레이아웃이 이미 커졌으므로 확대는 살짝만 얹는다. 둘 다 크게 주면
	# 옆 카드를 통째로 덮는다.
	var target_scale: float = 1.12 if want_hover else 1.0
	var target_tilt: float = 0.045 if want_hover else 0.0

	# 지수 감쇠 보간 - 프레임레이트에 안 흔들린다.
	var k := 1.0 - exp(-16.0 * delta)
	_lift = lerp(_lift, target_lift, k)
	_scale = lerp(_scale, target_scale, k)
	_tilt = lerp(_tilt, target_tilt, k)

	var sway := 0.0
	# 펼쳐지면 커진 만큼 좌우로 밀어 원래 자리에 중심이 남게 한다.
	# 안 그러면 카드가 오른쪽 아래로 자라나 이웃을 덮는다.
	var grow := Vector2.ZERO
	if _expanded:
		grow = (Vector2(W, H) - Vector2(W, H) * mini_scale) * -0.5
	position = base_pos + grow + Vector2(0.0, _lift + sway)
	rotation = base_rot + _tilt
	scale = Vector2(_scale, _scale)
	z_index = 50 if want_hover else index

	# ── 매 프레임 다시 그리지 않는다 ──────────────────────────────────────
	# position·rotation·scale 은 노드 변환이라 바뀌면 엔진이 알아서 다시 렌더한다.
	# queue_redraw() 가 필요한 건 **그려지는 내용**이 바뀔 때뿐이고, 여기서 내용을
	# 좌우하는 건 호버 여부(밝기)와 enabled(흐림) 둘뿐이다.
	#
	# 그런데 매 프레임 무조건 부르고 있었다. _draw() 는 draw_string 이 여러 번
	# 도는 무거운 함수인데, 손패와 상점을 합치면 카드가 20장 넘게 떠 있다 -
	# 프레임마다 스무 번씩 전부 다시 그리고 있었다. 카드가 13장에서 18장으로
	# 늘면서 그 비용이 체감될 만큼 커졌다.
	if want_hover != _drawn_hover or enabled != _drawn_enabled:
		_drawn_hover = want_hover
		_drawn_enabled = enabled
		queue_redraw()


## 규칙 카드와 특수 스킬은 표에서만 다르고 그리는 모양은 같은 뼈대를 쓴다.
func is_special() -> bool:
	return Specials.TABLE.has(card_id)


## 카드 일러스트. 없으면 null - 에셋이 없어도 카드가 성립한다.
## 네온 외곽선 색. 채도를 낮추고 밝기를 올린다.
##
## 원색 네온을 그대로 두르면 카드가 20장 깔린 상점에서 화면이 형광펜이 된다.
## 사이버틱한 인상은 **채도가 아니라 밝기 대비**에서 나온다 - 어두운 판 위에
## 밝고 흐린 선이 떠 있을 때가 가장 그렇게 보인다.
func _neon(base: Color) -> Color:
	var h := base.h
	var sat: float = minf(base.s, 0.42)
	var val: float = clampf(base.v * 1.25 + 0.18, 0.0, 1.0)
	return Color.from_hsv(h, sat, val, 1.0)


func _banner_tex() -> Texture2D:
	if card_id == "":
		return null
	var path := "res://assets/art/cards/%s.png" % card_id
	if not ResourceLoader.exists(path):
		return null
	var t := load(path)
	return t if t is Texture2D else null


func _data() -> Dictionary:
	if Specials.TABLE.has(card_id):
		return Specials.TABLE[card_id]
	if Cards.TABLE.has(card_id):
		return Cards.leveled(card_id, level)
	return {}


func _draw() -> void:
	var c: Dictionary = _data()
	if card_id == "" or c.is_empty():
		# 빈 자리 - 산 카드가 빠져나간 슬롯.
		var empty := UiKit.box(Color(0.10, 0.11, 0.14, 0.6), Color(0.22, 0.24, 0.30), 7)
		draw_style_box(empty, Rect2(Vector2.ZERO, card_size()))
		return

	var special := is_special()
	var cost := int(c["cost"])
	# 특수는 코스트와 무관하게 금색으로 통일한다. 한눈에 "이건 다른 종류" 여야 한다.
	# ── 왜 코스트 색이 아니라 축 색인가 ──────────────────────────────────
	# 상점에 스무 장이 깔렸을 때 먼저 알아야 하는 건 "얼마인가" 가 아니라
	# "무슨 종류인가" 다. 표적 모듈이 필요한 판에서 위치 모듈을 훑고 있으면
	# 아무리 싸도 소용이 없다. 코스트는 배지 숫자로 이미 보인다.
	var axis := String(c.get("axis", ""))
	var axis_label := Axes.label(axis) if axis != "" else ""
	var ccol: Color = UiKit.ACCENT if special else (
		Axes.color(axis) if axis != "" else UiKit.cost_color(cost))
	var s := card_size()
	# 카드는 한 장 안에서 크기가 9~14 로 섞인다. 작은 글씨는 v2 를 써야 읽힌다.
	var f := UiKit.font()
	var fs := UiKit.font(11)

	var body := Color(0.115, 0.130, 0.170) if not special else Color(0.175, 0.150, 0.105)
	var border := ccol
	if not enabled:
		body = Color(0.075, 0.082, 0.100)
		border = Color(0.24, 0.26, 0.32)

	var k: float = s.x / W          # 미니 배율
	var dim := Color(1, 1, 1) if enabled else Color(0.55, 0.55, 0.6)
	var neon := _neon(border)

	# ── 프레임 ───────────────────────────────────────────────────────────
	# 오른쪽 위만 깎는다. 네 귀를 다 깎으면 팔각형이 되고, 대각으로 둘을 깎으면
	# 카드처럼 보인다 - 지금은 카드가 아니라 **패널에 꽂힌 모듈**이어야 한다.
	# 한 귀만 깎으면 방향이 생기면서도 사각형으로 남는다.
	var cut: float = 14.0 * k
	var shape := PackedVector2Array([
		Vector2(0, 0), Vector2(s.x - cut, 0), Vector2(s.x, cut),
		Vector2(s.x, s.y), Vector2(0, s.y),
	])
	draw_colored_polygon(shape, body)

	# 왼쪽 축 색 기둥. 이 블록이 무슨 축인지 글자를 읽기 전에 갈린다.
	draw_rect(Rect2(0, 0, 4.0 * k, s.y), neon)
	# 기둥 옆으로 흘러나오는 빛 한 겹.
	draw_rect(Rect2(4.0 * k, 0, 10.0 * k, s.y), Color(neon.r, neon.g, neon.b, 0.07))

	var outline := PackedVector2Array(shape)
	outline.append(shape[0])
	draw_polyline(outline, Color(neon.r, neon.g, neon.b, 0.85 if enabled else 0.35),
		1.4, true)
	# 바깥으로 한 겹 더 옅게. 선 하나만으로는 발광으로 안 읽힌다.
	draw_polyline(outline, Color(neon.r, neon.g, neon.b, 0.14), 4.0, true)

	# ── 글 ───────────────────────────────────────────────────────────────
	var pad := 14.0 * k
	var axis_size: int = int(9.0 * k) + 1
	var name_size: int = int(15.0 * k) + 1
	var text_size: int = int(10.0 * k) + 1

	# 축 라벨. 궁극기는 축이 없으므로 소유 대원을 적는다 - 누구 것인지가
	# 이 블록을 살지 말지 정하는 가장 큰 정보다.
	var top_label := axis_label
	if axis == "":
		top_label = "ULT · %s" % String(UnitData.TABLE.get(c.get("unit", ""), {}).get("name", ""))
	draw_string(UiKit.font_role("large"), Vector2(pad, 16.0 * k), top_label,
		HORIZONTAL_ALIGNMENT_LEFT, s.x - pad - 34.0 * k, axis_size,
		Color(ccol.r, ccol.g, ccol.b, 0.95 if enabled else 0.5))

	# 비용. 배지를 오른쪽 위 깎인 귀 아래에 놓는다.
	var badge_r := 11.0 * k
	var badge_at := Vector2(s.x - pad - badge_r + 2.0, 16.0 * k + badge_r - 5.0)
	draw_circle(badge_at, badge_r, ccol if enabled else Color(0.3, 0.32, 0.38))
	var cost_txt := str(cost)
	var cw := fs.get_string_size(cost_txt, HORIZONTAL_ALIGNMENT_LEFT, -1,
		int(12.0 * k) + 1).x
	draw_string(fs, badge_at + Vector2(-cw * 0.5, 4.5 * k), cost_txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(12.0 * k) + 1, Color(0.06, 0.07, 0.1))

	# 이름.
	draw_string(f, Vector2(pad, 38.0 * k), String(c["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, s.x - pad - 30.0 * k, name_size, dim)

	# ── 규칙 한 줄 ───────────────────────────────────────────────────────
	# 화살표 앞이 조건, 뒤가 행동이다. 색만 갈라 두면 라벨이 필요 없다.
	var rule_text := String(c["text"])
	var arrow := rule_text.find("→")
	var ty := 54.0 * k
	var body_w := s.x - pad * 2.0
	var line_h := float(text_size) + 3.0
	var room: float = s.y - ty - 8.0 * k
	var cap: int = maxi(1, int(room / line_h))
	if arrow >= 0:
		var cond_line := rule_text.substr(0, arrow).strip_edges()
		var act_line := rule_text.substr(arrow + 1).strip_edges()
		var used := _wrapped(fs, cond_line, Vector2(pad, ty), body_w, text_size,
			Color(0.62, 0.66, 0.74) * dim, 1)
		ty += used + 2.0
		_wrapped(fs, act_line, Vector2(pad, ty), body_w, text_size,
			UiKit.ACCENT * dim, maxi(1, cap - 1))
	else:
		_wrapped(fs, rule_text, Vector2(pad, ty), body_w, text_size,
			Color(0.80, 0.84, 0.90) * dim, cap)

	# 상태 문구. 오른쪽 아래에 붙인다 - 규칙 글과 자리를 다투지 않는다.
	if note != "":
		var nw := fs.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(10.0 * k) + 1).x
		draw_string(fs, Vector2(s.x - pad - nw, s.y - 7.0 * k), note,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(10.0 * k) + 1, UiKit.BAD)


## 단어 단위로 접어 그리고, 소비한 세로 높이를 돌려준다.
##
## max_lines 를 주면 그 줄에서 끊고 마지막 줄 끝에 말줄임표를 붙인다.
## 손패의 미니 카드는 높이가 121px 뿐이라 긴 설명(최후의 수호 등)이 카드 밖으로
## 흘러나갔다. 잘린 글자가 다음 카드 위에 얹혀서 둘 다 못 읽는 상태였다.
## 전문은 카드에 마우스를 올리면 확대되어 보인다.
func _wrapped(f: Font, text: String, at: Vector2, max_w: float, fsize: int,
		col: Color, max_lines: int = 0) -> float:
	var lines: Array[String] = []
	var line := ""
	for w in text.split(" "):
		var probe := w if line == "" else line + " " + w
		if f.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > max_w and line != "":
			lines.append(line)
			line = w
		else:
			line = probe
	if line != "":
		lines.append(line)

	var clipped := max_lines > 0 and lines.size() > max_lines
	if clipped:
		lines.resize(max_lines)
		# 말줄임표가 들어갈 자리를 만든다. 안 그러면 "…" 가 폭을 넘겨 또 잘린다.
		var last: String = lines[max_lines - 1]
		while last.length() > 1 and f.get_string_size(
				last + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > max_w:
			last = last.substr(0, last.length() - 1)
		lines[max_lines - 1] = last + "..."

	var y := 0.0
	for l in lines:
		draw_string(f, at + Vector2(0, y), l, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
		y += fsize + 3.0
	return y
