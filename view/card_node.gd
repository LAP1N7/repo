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
const W: float = 210.0
const H: float = 142.0

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
	return Vector2(W, H) * (mini_scale if mini else 1.0)


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
	return mini


func place(pos: Vector2, _rot: float = 0.0) -> void:
	# 회전은 안 쓴다. 목록에서 블록이 기울면 줄이 안 맞아 보인다.
	base_pos = pos
	base_rot = 0.0
	position = pos
	rotation = 0.0


func _on_gui_input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)


func _process(delta: float) -> void:
	var want_hover := _hover and enabled

	# ── 들려 올라오면서 앞으로 ───────────────────────────────────────────
	# 예전 손맛으로 되돌린다. 위로 들리고 살짝 커진다. 기울이지는 않는다 -
	# 목록에서 기울면 줄이 안 맞아 보인다.
	var target_lift: float = -14.0 if want_hover else 0.0
	var target_scale: float = 1.06 if want_hover else 1.0
	var k := 1.0 - exp(-16.0 * delta)
	_lift = lerp(_lift, target_lift, k)
	_scale = lerp(_scale, target_scale, k)
	position = base_pos + Vector2(0.0, _lift)
	rotation = 0.0
	scale = Vector2(_scale, _scale)
	z_index = 50 if want_hover else index

	if want_hover != _drawn_hover or enabled != _drawn_enabled:
		_drawn_hover = want_hover
		_drawn_enabled = enabled
		queue_redraw()


## 글자를 하나씩 놓아 자간을 벌린다.
func _draw_tracked(f: Font, text: String, at: Vector2, fsize: int,
		track: float, col: Color) -> void:
	var x := at.x
	for i in text.length():
		var ch := text[i]
		draw_string(f, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)
		x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x + track


## 이 폭에서 몇 줄이 나오는가. 세로 가운데 정렬에 쓴다.
func _count_lines(f: Font, text: String, max_w: float, fsize: int, cap: int) -> int:
	if text == "":
		return 0
	var lines := 0
	var cur := ""
	for w in text.split(" "):
		var probe := w if cur == "" else cur + " " + w
		if f.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > max_w \
				and cur != "":
			lines += 1
			cur = w
		else:
			cur = probe
	if cur != "":
		lines += 1
	return mini(lines, cap)


## 둥근 모서리 한 귀. 폴리곤에 호 위의 점들을 이어 붙인다.
##
## StyleBoxFlat 는 반듯한 사각만 둥글게 해 준다. 오른쪽 위가 파인 모양은
## 폴리곤으로 직접 그려야 하고, 그러면 모서리도 직접 굴려야 한다.
func _arc_to(pts: PackedVector2Array, c: Vector2, rad: float,
		a0: float, a1: float, inner: bool = false) -> void:
	var steps := 14
	for i in steps + 1:
		var t := float(i) / float(steps)
		var a: float = a0 + (a1 - a0) * t
		pts.append(c + Vector2(cos(a), sin(a)) * (rad if not inner else rad))


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
	# 참조 그림 그대로다. 직선으로 가되 **꺾이는 곳은 전부 곡선**이다.
	#   · 둥근 모서리 사각, 얇은 축색 테두리
	#   · 오른쪽 위가 계단처럼 파이고(노치) 그 안쪽 꺾임도 둥글다
	#   · 노치 안에 주황 사선 띠. 위아래를 선으로 마감하고 빛을 조금 흘린다
	#   · 노치 오른쪽 끝에 3/4 원 배지(아래를 조금 자른다)
	#   · 왼쪽 아래에 두꺼운 축색 선
	var r := 16.0 * k                 # 바깥 모서리 반지름
	var ir := 11.0 * k                # 노치 꺾임 반지름
	var nh := 30.0 * k                # 노치 깊이
	var nx := s.x * 0.50              # 노치가 시작하는 x
	var pts := PackedVector2Array()

	_arc_to(pts, Vector2(r, r), r, PI, PI * 1.5)                    # 왼쪽 위
	pts.append(Vector2(nx - ir, 0))
	# 윗변 -> 노치로 꺾여 내려가는 곳. 중심이 안쪽에 있어야 선이 이어진다.
	# -PI/2 에서 0 으로 돌면 (nx-ir, 0) 에서 (nx, ir) 로 매끄럽게 넘어간다.
	_arc_to(pts, Vector2(nx - ir, ir), ir, -PI * 0.5, 0.0)
	pts.append(Vector2(nx, nh - ir))
	# 노치 바닥으로 꺾이는 안쪽 곡선.
	_arc_to(pts, Vector2(nx + ir, nh - ir), ir, PI, PI * 0.5)
	pts.append(Vector2(s.x - r, nh))
	_arc_to(pts, Vector2(s.x - r, nh + r), r, PI * 1.5, TAU)        # 오른쪽 위
	pts.append(Vector2(s.x, s.y - r))
	_arc_to(pts, Vector2(s.x - r, s.y - r), r, 0.0, PI * 0.5)       # 오른쪽 아래
	pts.append(Vector2(r, s.y))
	_arc_to(pts, Vector2(r, s.y - r), r, PI * 0.5, PI)              # 왼쪽 아래

	draw_colored_polygon(pts, body)
	var outline := PackedVector2Array(pts)
	outline.append(pts[0])
	draw_polyline(outline, Color(neon.r, neon.g, neon.b, 0.12), 5.0 * k, true)
	draw_polyline(outline, Color(neon.r, neon.g, neon.b, 0.95 if enabled else 0.35),
		1.6 * k, true)

	# ── 노치 안의 사선 띠 ────────────────────────────────────────────────
	# 양 끝을 사선 방향으로 맞춰 잘라 마감하고, 위아래에 얇은 선을 둘러
	# 띠 하나로 묶는다. 그 위에 빛을 한 겹 흘린다.
	# 아랫변이 노치 바닥선(nh)과 딱 맞게 떨어진다. 띠가 선 위에 얹힌 것이
	# 아니라 그 선의 일부로 읽힌다.
	var band_h := nh - 12.0 * k
	var band_y := nh - band_h - 1.0 * k
	var band_x0 := nx + 4.0 * k
	var band_x1 := s.x - 44.0 * k
	var slant := 8.0 * k
	var bar_w := 5.0 * k
	var bar_gap := 4.5 * k
	var hatch := Color(1.0, 0.44, 0.12, 1.0 if enabled else 0.25)
	var hx := band_x0
	while hx + bar_w + slant <= band_x1:
		draw_colored_polygon(PackedVector2Array([
			Vector2(hx + slant, band_y),
			Vector2(hx + slant + bar_w, band_y),
			Vector2(hx + bar_w, band_y + band_h),
			Vector2(hx, band_y + band_h),
		]), hatch)
		hx += bar_w + bar_gap
	# ── 왼쪽 아래 두꺼운 선 ──────────────────────────────────────────────
	draw_line(Vector2(r, s.y - 3.0 * k), Vector2(r + s.x * 0.32, s.y - 3.0 * k),
		Color(neon.r, neon.g, neon.b, 0.95 if enabled else 0.3), 5.0 * k)

	# ── 글 ───────────────────────────────────────────────────────────────
	var pad := 14.0 * k
	var axis_size: int = int(11.0 * k) + 1
	var name_size: int = int(20.0 * k) + 1
	var text_size: int = int(13.0 * k) + 1

	# 축 라벨. 궁극기는 축이 없으므로 소유 대원을 적는다 - 누구 것인지가
	# 이 블록을 살지 말지 정하는 가장 큰 정보다.
	var top_label := axis_label
	if axis == "":
		top_label = "ULT · %s" % String(UnitData.TABLE.get(c.get("unit", ""), {}).get("name", ""))
	draw_string(UiKit.font_role("large"), Vector2(pad, 25.0 * k), top_label,
		HORIZONTAL_ALIGNMENT_LEFT, s.x - pad - 34.0 * k, axis_size,
		Color(ccol.r, ccol.g, ccol.b, 0.95 if enabled else 0.5))

	# 비용. 배지를 오른쪽 위 깎인 귀 아래에 놓는다.
	# 3/4 원. 아래를 조금 잘라 띠에 얹힌 것처럼 보이게 한다.
	var badge_r := 16.0 * k
	# 3/4 원의 잘린 아랫변은 중심에서 r*sin(45도) 만큼 아래에 생긴다.
	# 그 변이 노치 바닥선과 맞도록 중심을 올린다.
	var badge_at := Vector2(s.x - badge_r - 10.0 * k,
		30.0 * k - badge_r * 0.7071 - 1.0 * k)
	var bcol: Color = ccol if enabled else Color(0.3, 0.32, 0.38)
	# 아래 1/4(90도)만 잘라낸다. 남는 호는 3/4 이고, 잘린 두 끝을 이으면
	# 아랫변이 평평해진다.
	var wedge := PackedVector2Array()
	var a_from := PI * 0.75
	var a_to := PI * 2.25
	var seg := 64
	for wi in seg + 1:
		var wa: float = a_from + (a_to - a_from) * float(wi) / float(seg)
		wedge.append(badge_at + Vector2(cos(wa), sin(wa)) * badge_r)
	draw_colored_polygon(wedge, bcol)
	var cost_txt := str(cost)
	var cost_size: int = int(14.0 * k) + 1
	var cw := fs.get_string_size(cost_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, cost_size).x
	draw_string(fs, badge_at + Vector2(-cw * 0.5, 6.0 * k), cost_txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, cost_size, Color(0.06, 0.07, 0.1))

	# 이름.
	_draw_tracked(f, String(c["name"]), Vector2(pad, 50.0 * k), name_size,
		1.6 * k, dim)

	# ── 규칙 한 줄 ───────────────────────────────────────────────────────
	# 화살표 앞이 조건, 뒤가 행동이다. 색만 갈라 두면 라벨이 필요 없다.
	var rule_text := String(c["text"])
	var arrow := rule_text.find("→")
	# ── 설명은 남은 자리의 가운데에 ──────────────────────────────────────
	# 이름 아래부터 블록 바닥까지가 설명이 쓸 수 있는 자리다. 위에 붙여 놓으면
	# 아래가 통째로 비어 블록이 반만 찬 것처럼 보인다.
	var body_top := 58.0 * k
	var body_bottom := s.y - 10.0 * k
	var ty := body_top
	var body_w := s.x - pad * 2.0
	var line_h := float(text_size) + 3.0
	var room: float = body_bottom - body_top
	var cap: int = maxi(1, int(room / line_h))
	# 실제로 몇 줄이 나오는지 먼저 세어 가운데로 민다.
	var used_lines := 0
	if arrow >= 0:
		used_lines = 1 + _count_lines(fs, rule_text.substr(arrow + 1).strip_edges(),
			body_w, text_size, maxi(1, cap - 1))
	else:
		used_lines = _count_lines(fs, rule_text, body_w, text_size, cap)
	ty = body_top + maxf(0.0, (room - float(used_lines) * line_h) * 0.5)
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
