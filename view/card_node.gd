class_name CardNode
extends Control

## 규칙 카드 한 장. 발라트로식 손맛 담당.
##
## 호버하면 들리고 살짝 커지고 기울어진다. 가만히 있어도 아주 약하게 흔들린다.
## 애니메이션은 Tween 이 아니라 _process 의 지수 감쇠 보간으로 돌린다.
## Tween 을 쓰면 카드가 재배치될 때마다 이전 Tween 과 싸워서 튄다.

signal clicked(node: CardNode)
signal banned(node: CardNode)

## 카드 한 장의 기준 크기.
##
## ── 왜 키웠는가 ──────────────────────────────────────────────────────────
## 128x168 은 손패에 여러 장 늘어놓기에는 알맞았지만 상점에서는 너무 작았다.
## 상점은 한 번에 예닐곱 장만 뜨고, 그 중 무엇을 사느냐가 이 게임에서 가장 큰
## 결정이다. 결정이 큰 화면일수록 물건이 커야 한다.
##
## 축 라벨과 이름이 한눈에 들어와야 "이번 상점에 표적이 둘 나왔다" 가 훑기만
## 해도 읽힌다. 손패는 mini 로 0.72배 줄여 쓰므로 거기 밀도는 그대로다.
const W: float = 152.0
const H: float = 196.0

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

var _ban_btn: Button


func setup(p_card_id: String, p_index: int, p_mini: bool = false,
		show_ban: bool = false) -> void:
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

	if show_ban:
		# 카드 자체를 누르면 구매, 이 버튼을 누르면 추방. 둘을 확실히 갈라 놓는다.
		# 이모지(🚫)는 맑은 고딕에 글리프가 없어서 빈 네모로 뜬다. 글자로 쓴다.
		var s := card_size()
		_ban_btn = UiKit.button(self, Vector2(8, s.y - 26), Vector2(s.x - 16, 20), UiText.t("card.ban", "제외"), 10)
		_ban_btn.tooltip_text = UiText.t("card.m01", "이 카드를 이번 런 전체에서 배제한다 (다음 스테이지에도 안 나옴)")
		_ban_btn.pressed.connect(func(): banned.emit(self))

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
func card_size() -> Vector2:
	if mini:
		return Vector2(W, H) * (1.0 if _expanded else 0.72)
	return Vector2(W, H) * (EXPAND if _expanded else 1.0)


## 원래 크기 카드를 펼칠 배율. 폭이 늘어나면 한 줄에 더 들어가고,
## 높이가 늘어나면 줄 수가 늘어난다. 둘 다 필요하다.
const EXPAND: float = 1.42


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
		if _ban_btn != null and is_instance_valid(_ban_btn):
			_ban_btn.position = Vector2(8, sz.y - 26)
			_ban_btn.size = Vector2(sz.x - 16, 20)
		queue_redraw()

	var target_lift: float = -18.0 if want_hover else 0.0
	# 레이아웃이 이미 커졌으므로 확대는 살짝만 얹는다. 둘 다 크게 주면
	# 옆 카드를 통째로 덮는다.
	var target_scale: float = 1.03 if want_hover else 1.0
	var target_tilt: float = 0.045 if want_hover else 0.0

	# 지수 감쇠 보간 - 프레임레이트에 안 흔들린다.
	var k := 1.0 - exp(-16.0 * delta)
	_lift = lerp(_lift, target_lift, k)
	_scale = lerp(_scale, target_scale, k)
	_tilt = lerp(_tilt, target_tilt, k)

	var sway := 0.0 if want_hover else sin(_t * 1.6) * 1.5
	# 펼쳐지면 커진 만큼 좌우로 밀어 원래 자리에 중심이 남게 한다.
	# 안 그러면 카드가 오른쪽 아래로 자라나 이웃을 덮는다.
	var grow := Vector2.ZERO
	if _expanded:
		grow = (Vector2(W, H) - Vector2(W, H) * 0.72) * -0.5
	position = base_pos + grow + Vector2(0.0, _lift + sway)
	rotation = base_rot + _tilt + (0.0 if want_hover else sin(_t * 1.1) * 0.006)
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

	var body := Color(0.20, 0.17, 0.12) if special else Color(0.16, 0.18, 0.23)
	var border := ccol
	if not enabled:
		body = Color(0.11, 0.12, 0.15)
		border = Color(0.24, 0.26, 0.32)

	# ── 프레임 ───────────────────────────────────────────────────────────
	# 둥근 모서리 대신 왼쪽 위·오른쪽 아래를 사선으로 깎는다. 네 귀퉁이를 다 깎으면
	# 팔각형이 되어 카드로 안 읽히고, 대각으로 둘만 깎으면 방향이 생긴다.
	# 궁극기 컷인의 사선 프레임과 같은 어법이다.
	var cut: float = 13.0 * (s.x / W)
	var shape := PackedVector2Array([
		Vector2(cut, 0), Vector2(s.x, 0), Vector2(s.x, s.y - cut),
		Vector2(s.x - cut, s.y), Vector2(0, s.y), Vector2(0, cut),
	])
	draw_colored_polygon(shape, body)

	# 네온 외곽선. 채도를 낮춰 쓴다 - 원색 그대로 두르면 카드가 20장 깔렸을 때
	# 화면이 통째로 형광펜이 된다. 밝기만 올리고 채도는 깎는다.
	var neon := _neon(border)
	var outline := PackedVector2Array(shape)
	outline.append(shape[0])
	draw_polyline(outline, neon, 1.6, true)
	# 안쪽으로 한 겹 더 희미하게. 선 하나만으로는 발광으로 안 읽힌다.
	draw_polyline(outline, Color(neon.r, neon.g, neon.b, 0.22), 4.0, true)

	# ── 일러스트 배너 (레이어: 배경판 위, 텍스트 아래)
	# assets/art/cards/<id>.png 가 있으면 상단 띠에 깔린다. 없으면 그냥 비어 있다.
	var banner := _banner_tex()
	if banner != null:
		var bh := s.y * BANNER_RATIO
		draw_texture_rect(banner, Rect2(Vector2(1, 6), Vector2(s.x - 2, bh)), false)
		# 아래쪽을 어둡게 덮어 글자가 그림 위에서도 읽히게 한다.
		draw_rect(Rect2(Vector2(1, 5 + bh * 0.45), Vector2(s.x - 2, bh * 0.55)),
			Color(body.r, body.g, body.b, 0.75))

	# 코스트 색 띠 - 멀리서도 비싼 카드가 구분된다.
	# 왼쪽 위가 깎였으므로 띠도 같이 깎아야 프레임 밖으로 안 삐져나온다.
	draw_colored_polygon(PackedVector2Array([
		Vector2(cut + 1, 1), Vector2(s.x - 1, 1),
		Vector2(s.x - 1, 5), Vector2(cut - 3, 5),
	]), neon)

	var pad := 9.0
	# 미니 카드는 폭이 92px 뿐이라 12px 로 두면 "거리 유지" 가 한 글자 잘린다.
	# 미니 폭은 92px 다. 11 로 두면 "불굴의 의지" 가 "불굴의 의" 로 잘린다.
	var name_size := 17 if not _is_mini() else 10
	var text_size := 12 if not _is_mini() else 10
	var dim := Color(1, 1, 1) if enabled else Color(0.55, 0.55, 0.6)

	# 코스트 배지
	# 미니 배지를 11 → 9 로 줄였다. "최후의 수호" 가 "최후의 수" 로 잘리던
	# 2글자분 폭이 여기서 나온다.
	var badge_r := 13.0 if not _is_mini() else 8.0
	var badge_at := Vector2(s.x - pad - badge_r, pad + badge_r + 4.0)
	draw_circle(badge_at, badge_r, ccol)
	var cost_txt := str(cost)
	var cw := fs.get_string_size(cost_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(fs, badge_at + Vector2(-cw * 0.5, 5), cost_txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.06, 0.07, 0.1))

	# 이름. 코스트 배지가 차지하는 폭만 정확히 비켜 준다.
	# 넉넉히 빼면 미니 카드에서 "거리 유지" 같은 이름이 잘린다.
	# 영문 축 라벨. 전부 영문이면 한국어 톤과 충돌하고 전부 한글이면 축이
	# 안 보인다. 축만 영문으로 두면 계기판처럼 읽히면서 본문은 그대로다.
	# 궁극기는 축이 없다. 대신 ULTIMATE 을 같은 자리에 적는다. 이 줄이 없으면
	# 그 자리가 비어서 이름이 위로 붙고, 아래 부제와 글자가 겹친다.
	var top_label := axis_label if axis != "" else "ULTIMATE"
	draw_string(UiKit.font_role("large"), Vector2(pad, pad + 11.0), top_label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10 if not _is_mini() else 8,
			Color(ccol.r, ccol.g, ccol.b, 0.95))

	draw_string(f if not _is_mini() else fs, Vector2(pad, pad + 30.0), String(c["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, s.x - pad * 2 - (badge_r * 2.0 + 2.0),
		name_size, UiKit.TEXT * dim)

	# 궁극기는 어느 직업 전용인지가 구매 판단의 전부다. 발동은 전투당 1회로 통일이라
	# 카드마다 다른 값이 아니고, 그래서 표기에서 뺐다.
	# ── 발동 횟수를 카드에 적는다 ────────────────────────────────────────
	# 전술과 궁극기를 가르는 유일한 규칙인데 화면 어디에도 안 적혀 있었다.
	# [구호](아군 HP<50% -> 회복)가 전투당 한 번인지, 조건이 유지되는 동안 매 틱인지
	# 카드만 봐서는 알 수 없었다. 답은 후자다 - 전술은 조건이 맞을 때마다 발동한다.
	#
	# 중첩 걱정은 없다. 조건을 매 틱 다시 보므로 회복해서 50%를 넘기는 순간
	# 저절로 꺼지고, 대상 선택이 만피 아군을 제외하므로 헛도는 일도 없다.
	# 미니 카드에는 부제를 안 적는다. 위에 ULTIMATE / TARGET 라벨이 이미 있어
	# 같은 뜻을 두 번 적는 셈이고, 폭이 좁아 이름과 글자가 겹쳤다.
	if not _is_mini():
		var tag := ""
		var tcol := UiKit.ACCENT
		if special:
			tag = UiText.t("card.special_tag", "궁극기 · %s 전용 · 전투당 1회") % UnitData.TABLE[c["unit"]]["name"]
		else:
			tag = UiText.t("card.tactic_tag", "전술 · 조건이 맞는 한 매 틱 발동")
			tcol = UiKit.MUTED
		draw_string(fs, Vector2(pad, pad + 36.0), tag,
			HORIZONTAL_ALIGNMENT_LEFT, s.x - pad * 2, 10, tcol * dim)

	# 규칙 문장 - 조건과 행동을 두 줄로 쪼개 보여준다. 카드 한 장 = 한 문장.
	var parts: PackedStringArray = String(c["text"]).split("→")
	var cond_line := parts[0].strip_edges() if parts.size() > 0 else ""
	var act_line := parts[1].strip_edges() if parts.size() > 1 else ""

	# ── 미니 카드는 남은 높이에 맞춰 줄 수를 자른다 ───────────────────────
	# 세로가 121px 뿐이라 그냥 접으면 [최후의 수호] 처럼 긴 설명이 카드 밖으로
	# 흘러나가 옆 카드 위에 얹힌다.
	#
	# `조건`·`행동` 라벨을 빼는 것이 먼저다. 둘이 38px 을 먹는데 그건 본문 3줄에
	# 해당한다. 라벨이 없어도 색으로 구분된다 - 조건은 흰색, 행동은 금색이다.
	# 그 뒤에 남은 높이를 줄 높이로 나눠 조건·행동에 절반씩 준다.
	# 이제 전술에도 태그 한 줄이 붙으므로 본문 시작 높이를 맞춘다.
	# 미니는 태그가 없으니 예전 높이 그대로 둔다.
	# 미니 카드도 궁극기면 태그 한 줄(pad+38)이 붙는다. 0.42(=50px)로 시작하면
	# 그 태그와 조건 첫 줄이 겹친다. 궁극기만 조금 내려서 시작한다.
	# 본문 시작 높이. 큰 카드는 0.48(높이의 절반)이라 제목과 본문 사이가 통째로
	# 비어 보였다. 라벨·이름·부제가 pad+36 에서 끝나므로 그 바로 아래면 된다.
	var ty: float = s.y * ((0.47 if special else 0.42) if _is_mini() else 0.32)
	var line_h := float(text_size) + 3.0

	# 아래로 침범하면 안 되는 선. 큰 카드는 [배제] 버튼과 안내문이 하단을 쓴다.
	var floor_y: float = s.y - (36.0 if _ban_btn else 12.0)
	if note != "":
		floor_y -= 14.0

	var cap := 0
	if _is_mini():
		var room: float = s.y - 10.0 - ty - 6.0
		cap = maxi(1, int(room / line_h) / 2)
	elif _expanded:
		# 펼친 카드는 자르지 않는다. 전문을 보여 주려고 키운 것이므로
		# 여기서 또 말줄임을 하면 키운 의미가 없다. 0 이면 무제한이다.
		draw_string(fs, Vector2(pad, ty), UiText.t("card.cond", "조건"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiKit.MUTED * dim)
		ty += 15.0
	else:
		# 라벨 두 개(15+15)와 사이 여백(8)을 뺀 나머지를 조건·행동이 나눠 쓴다.
		var room2: float = floor_y - ty - 38.0
		cap = maxi(1, int(room2 / line_h) / 2)
		draw_string(fs, Vector2(pad, ty), UiText.t("card.cond", "조건"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiKit.MUTED * dim)
		ty += 15.0

	ty += _wrapped(fs, cond_line, Vector2(pad, ty), s.x - pad * 2, text_size,
		UiKit.TEXT * dim, cap)

	ty += 6.0 if _is_mini() else 8.0
	if not _is_mini():
		draw_string(fs, Vector2(pad, ty), UiText.t("card.act", "행동"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiKit.MUTED * dim)
		ty += 15.0

	_wrapped(fs, act_line, Vector2(pad, ty), s.x - pad * 2, text_size,
		UiKit.ACCENT * dim, cap)

	if note != "":
		var ny := s.y - (32.0 if _ban_btn else 9.0)
		draw_string(fs, Vector2(pad, ny), note, HORIZONTAL_ALIGNMENT_LEFT,
			s.x - pad * 2, 10, UiKit.BAD)


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
