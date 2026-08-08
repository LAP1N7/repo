class_name CommandScreen
extends Control

## 보조 지휘. 예산으로 부대 자체를 키우는 곳.
##
## ── 왜 별도 화면인가 ─────────────────────────────────────────────────────
## 상점이 "이번 교전을 어떻게 풀까" 라면 여기는 "이 작전 전체를 어떻게 끌고
## 갈까" 다. 성격이 달라서 같은 화면에 두면 둘 다 흐려진다.
##
## 그리고 여기서만 MIRA 가 화면에 선다. 스토리에서 목소리로만 있던 존재가
## 실제로 옆에 서 있는 화면이 하나쯤 있어야 "보조 에이전트" 라는 설정이 산다.
##
## ── 왜 전부 보이는가 ─────────────────────────────────────────────────────
## 후보를 무작위로 열면 "운이 좋아서 강해졌다" 가 되고 그건 플레이어가 짠 것이
## 아니다. 전부 보이게 두고 **무엇을 먼저 살 것인가**로 선택을 만든다.
## 단계마다 값이 오르므로 다 살 수는 없다.

signal back()

const ART_W: float = 380.0

var run: RunState
var root: Control
var lbl_budget: Label
var lbl_note: Label
## 실험용 장치 목록의 현재 쪽. 한 쪽에 4장씩.
var swap_page: int = 0

## 기둥별 강화 칸 목록. 호버로 칸이 자라면 아래가 밀려야 하므로 매 프레임
## 다시 쌓는다.
var _stacks: Array = []
## 기둥 아래에 붙어 같이 밀려야 하는 것들(실험용 장치). {node, col, y}
var _followers: Array = []


func setup(p_run: RunState) -> void:
	run = p_run
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(1280, 720)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06)
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# ── 왼쪽: MIRA ───────────────────────────────────────────────────────
	# 스토리와 같은 어법으로 사선을 준다. 아트가 없으면 회색 자리만 남는다.
	var portrait := _ArtSlot.new()
	portrait.position = Vector2.ZERO
	portrait.size = Vector2(ART_W, 720)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)

	UiKit.frame(self, Color(0.35, 0.75, 1.0))

	UiKit.label(self, Vector2(ART_W + 40, 24), Vector2(600, 36),
		UiText.t("cmd.head", "보조 지휘"), 26, Color(0.55, 0.88, 1.0))
	UiKit.label(self, Vector2(ART_W + 40, 62), Vector2(700, 22),
		UiText.t("cmd.sub", "예산으로 부대 자체를 키웁니다. 모듈과 달리 작전이 끝날 때까지 남습니다."),
		12, UiKit.MUTED)

	lbl_budget = UiKit.label(self, Vector2(1000, 26), Vector2(240, 32), "", 22, UiKit.ACCENT)
	lbl_budget.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# 안내문은 맨 아래 왼쪽. 상점으로 버튼(1040~)과 x 가 안 겹친다.
	lbl_note = UiKit.label(self, Vector2(ART_W + 40, 648), Vector2(600, 22), "", 12, UiKit.BAD)

	var b := UiKit.button(self, Vector2(1040, 656), Vector2(200, 40),
		UiText.t("cmd.back", "◀  상점으로"), 15)
	b.pressed.connect(func(): back.emit())

	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	refresh()


func refresh() -> void:
	for c in root.get_children():
		c.queue_free()
	_stacks.clear()
	_followers.clear()
	lbl_budget.text = UiText.t("shop.budget", "예산  %d") % run.budget

	# ── 분류마다 한 기둥 ────────────────────────────────────────────────
	# 예전에는 열한 줄을 세로로 죽 늘어놓았다. 분류 머리글이 사이사이 끼어
	# 있었지만, 줄 높이가 다 같아서 **어디서 분류가 바뀌는지**가 안 보였다.
	#
	# 기둥으로 세우면 분류가 곧 자리가 된다. "전투를 밀지 경제를 밀지" 가
	# 화면 구조 자체로 읽히고, 그게 이 화면에서 하는 유일한 고민이다.
	var x0 := ART_W + 36.0
	var colw := (1240.0 - x0) / float(Command.GROUPS.size())
	for _i in Command.GROUPS.size():
		_stacks.append([])
	for gi in Command.GROUPS.size():
		var group := Command.GROUPS[gi]
		var cx := x0 + float(gi) * colw
		var head := _Pillar.new()
		head.position = Vector2(cx, 96)
		head.size = Vector2(colw - 12.0, _Pillar.H)
		head.title = group
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(head)

		var y := 96.0 + _Pillar.H + 14.0
		for id in Command.ids_in(group):
			var cell := _Cell.new()
			cell.position = Vector2(cx, y)
			cell.size = Vector2(colw - 12.0, _Cell.BASE_H)
			cell.id = id
			cell.level = run.command_level(id)
			cell.price = Command.price(cell.level)
			cell.affordable = cell.price >= 0 and run.budget >= cell.price
			cell.now = Command.amount(id, cell.level)
			cell.bought.connect(_on_buy)
			root.add_child(cell)
			_stacks[gi].append(cell)
			y += _Cell.BASE_H + 12.0

		# 확률은 항목이 하나뿐이라 기둥 아래가 통째로 빈다. 실험용 장치를
		# 그 자리에 넣는다 - 둘 다 "무엇이 나오게 할 것인가" 라 성격도 맞는다.
		if group == "확률":
			# ── 궁극기 합성은 여기 없다 ──────────────────────────────────
			# 잠깐 이 위에 뒀다가 뺐다. 궁극기 여섯 줄이 들어오니 실험용 장치가
			# 화면 아래로 밀려 잘렸고, 무엇보다 **합성은 예산만의 문제가 아니다** -
			# 같은 카드를 두 장 들고 있어야 한다. 그러면 카드가 보이는 곳,
			# 즉 상점 손패에 있어야 맞다.
			_swap_section(Vector2(cx, y + 10.0), colw - 12.0)
			# 실험용 장치는 확률 기둥의 유일한 칸 아래에 있다. 그 칸이 펼쳐지면
			# 같이 내려가야 "밀려났다" 로 읽힌다.
			for n in root.get_children():
				if n is Control and not (n in _stacks[gi]) \
						and (n as Control).position.x >= cx - 1.0 \
						and (n as Control).position.y > y:
					_followers.append({"node": n, "col": gi,
						"y": (n as Control).position.y})


## ── 밀려났다가 돌아온다 ─────────────────────────────────────────────────
## 펼쳐진 칸이 아래 칸을 **덮으면** 그 칸이 사라진 것처럼 보인다. 밀어내면
## 사라지지 않고 자리를 비켜 준 것이 되고, 손을 떼면 되돌아온다.
##
## 자리를 매 프레임 다시 쌓는 이유는 칸 높이가 보간 중이기 때문이다. 목표
## 위치만 잡아 주고 실제 이동은 각자 지수 감쇠로 따라가게 두면, 여러 칸이
## 동시에 움직여도 한 덩어리로 밀리는 것처럼 보인다.
func _process(delta: float) -> void:
	if _stacks.is_empty():
		return
	var k := 1.0 - exp(-14.0 * delta)
	var shift: Array[float] = []
	for gi in _stacks.size():
		var y := 96.0 + _Pillar.H + 14.0
		for cell in _stacks[gi]:
			if not is_instance_valid(cell):
				continue
			cell.position.y = lerpf(cell.position.y, y, k)
			y += cell.drawn_h() + 12.0
		# 이 기둥이 원래 높이보다 얼마나 자랐는가. 아래 붙은 것들이 그만큼 내려간다.
		var base := 96.0 + _Pillar.H + 14.0 + float(_stacks[gi].size()) * (_Cell.BASE_H + 12.0)
		shift.append(y - base)
	for f in _followers:
		var n = f["node"]
		if not is_instance_valid(n):
			continue
		n.position.y = lerpf(n.position.y, float(f["y"]) + shift[int(f["col"])], k)


func _on_buy(id: String) -> void:
	lbl_note.text = run.command_buy(id)
	refresh()


## ── 실험용 장치 ──────────────────────────────────────────────────────────
## 보유 모듈 하나를 같은 축의 다른 모듈로 바꾼다.
##
## 축을 넘어가면 안 된다. 표적을 위치로 바꿀 수 있으면 축의 의미가 사라진다.
## 축 안에서만 도니까 "표적 교리를 다듬는다" 가 된다.
func _swap_section(at: Vector2, w: float) -> void:
	var head := _Pillar.new()
	head.position = at
	head.size = Vector2(w, _Pillar.H)
	head.title = UiText.t("cmd.swap_head", "실험용 장치")
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(head)

	# 값을 머리글 옆에 박아 둔다. 누르기 전에 얼마가 드는지 모르면 그건
	# 선택이 아니라 도박이다.
	UiKit.label(root, Vector2(at.x + 4, at.y + _Pillar.H + 6.0), Vector2(w - 8, 30),
		UiText.t("cmd.swap_cost", "한 번 바꿀 때마다 예산 %d.  같은 축 안에서만 바뀝니다.")
			% Command.SWAP_COST, 10, UiKit.MUTED, true)

	if run.hand.is_empty():
		UiKit.label(root, Vector2(at.x + 4, at.y + _Pillar.H + 40.0), Vector2(w - 8, 18),
			UiText.t("cmd.swap_none", "보유 모듈이 없습니다."), 11, UiKit.FAINT)
		return

	var owned: Array[String] = []
	for cid in run.hand:
		if Cards.TABLE.has(cid):
			owned.append(cid)
	var per := 4
	var pages := int(ceil(owned.size() / float(per)))
	swap_page = 0 if pages == 0 else posmod(swap_page, pages)

	var y := at.y + _Pillar.H + 42.0
	for cid in owned.slice(swap_page * per, swap_page * per + per):
		var c: Dictionary = Cards.TABLE[cid]
		var b := _Swap.new()
		b.position = Vector2(at.x, y)
		b.size = Vector2(w, 30)
		b.label = String(c["name"])
		b.tint = Axes.color(String(c.get("axis", "")))
		b.enabled = run.budget >= Command.SWAP_COST
		b.pressed_id.connect(func(id: String):
			lbl_note.text = run.command_swap(id)
			refresh()
		)
		b.id = cid
		root.add_child(b)
		y += 34.0

	if pages > 1:
		var nx := UiKit.button(root, Vector2(at.x, y + 4), Vector2(w, 26),
			UiText.t("cmd.swap_more", "다음 %d/%d") % [swap_page + 1, pages], 11)
		nx.pressed.connect(func():
			swap_page += 1
			refresh()
		)


# ── 조각 ─────────────────────────────────────────────────────────────────

## MIRA 일러스트 자리. 오른쪽 변을 사선으로 잘라 스토리·컷인과 어법을 맞춘다.
##
## Polygon2D 를 쓰는 이유는 Control 의 clip_contents 가 사각형만 자르기 때문이다.
## 사선으로 자르려면 도형을 직접 만들고 UV 를 손으로 계산하는 수밖에 없다.
## (battle_view 의 궁극기 컷인과 같은 방식)
class _ArtSlot extends Control:
	const SKEW: float = 60.0

	## 자리를 채우고 나서 한 번 더 키우는 배율. 1.0 이면 딱 맞게 들어간다.
	## 1.35 로 키웠다가 80% 로 내렸다. 화면을 장악하는 것과 글을 가리는 것은
	## 종이 한 장 차이고, 여기는 읽는 화면이지 보는 화면이 아니다.
	const ZOOM: float = 1.08

	## 위에서 잘라 낼 비율. 인물 사진은 머리 위 여백이 넓어 그대로 두면
	## 얼굴이 화면 한가운데로 내려앉는다.
	const FACE_TOP: float = 0.06

	func _ready() -> void:
		var tex := UiKit.art(["command", "standing"], "ai")
		if tex == null:
			return
		var s := size
		var shape := _shape()
		# ── 잘리더라도 크게 ──────────────────────────────────────────────
		# 폭에 맞추면 인물이 자리 안에 얌전히 들어가지만 존재감이 없다. 궁극기
		# 컷인이 그렇듯, 인물은 **틀을 넘칠 때** 화면을 장악한다.
		#
		# 세로를 기준으로 채우고 가로 배율을 한 번 더 얹는다. 넘치는 쪽은
		# 자른다 - 얼굴만 살아 있으면 잘린 어깨는 오히려 압박감이 된다.
		var ts := Vector2(tex.get_width(), tex.get_height())
		var k: float = maxf(s.x / ts.x, s.y / ts.y) * ZOOM
		# 가로는 가운데, 세로는 얼굴이 위쪽에 오도록 위에서 조금만 내린다.
		var off := Vector2((s.x - ts.x * k) * 0.5, -ts.y * k * FACE_TOP)
		var uv := PackedVector2Array()
		for pt in shape:
			uv.append((pt - off) / k)
		var poly := Polygon2D.new()
		poly.polygon = shape
		poly.uv = uv
		poly.texture = tex
		add_child(poly)

	func _shape() -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(0, 0), Vector2(size.x, 0),
			Vector2(size.x - SKEW, size.y), Vector2(0, size.y),
		])

	func _draw() -> void:
		draw_colored_polygon(_shape(), Color(0.06, 0.12, 0.18))
		draw_line(Vector2(size.x, 0), Vector2(size.x - SKEW, size.y),
			Color(0.35, 0.75, 1.0, 0.8), 2.0)


## 파란 홀로그램 줄. 스토리 로그 화면과 같은 어법이다.
class _Holo extends Control:
	func _draw() -> void:
		var s := size
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.13, 0.20, 0.85))
		draw_rect(Rect2(Vector2.ZERO, s), Color(0.35, 0.75, 1.0, 0.35), false, 1.0)
		var y := 0.0
		while y < s.y:
			draw_line(Vector2(0, y), Vector2(s.x, y), Color(0, 0, 0, 0.18), 1.0)
			y += 3.0


## ── 분류 머리 ────────────────────────────────────────────────────────────
## 사선으로 자른 띠. 전투 화면 호버 판과 같은 어법이라 새로 배울 게 없다.
class _Pillar extends Control:
	## 분류 이름은 이 화면의 목차다. 항목 이름(13pt)과 같은 크기로 두면
	## 목차인지 항목인지 구분이 안 된다. 한 단 위로 올린다.
	const H: float = 38.0

	var title: String = ""

	func _draw() -> void:
		var s := size
		var cut := 12.0
		var shape := PackedVector2Array([
			Vector2(cut, 0), Vector2(s.x, 0), Vector2(s.x, s.y - cut),
			Vector2(s.x - cut, s.y), Vector2(0, s.y), Vector2(0, cut),
		])
		draw_colored_polygon(shape, Color(0.07, 0.16, 0.24, 0.95))
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		draw_polyline(line, Color(0.35, 0.75, 1.0, 0.6), 1.5, true)
		draw_rect(Rect2(0, cut, 4, s.y - cut), Color(0.45, 0.85, 1.0, 0.9))
		draw_string(UiKit.font(18), Vector2(14, 26), title,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.68, 0.93, 1.0))


## ── 강화 한 칸 ───────────────────────────────────────────────────────────
##
##   화력 증폭
##   □ □ □          [업그레이드 -4]
##
## 손을 올리면 칸이 조금 자라면서 아래에 설명이 펼쳐진다. 설명을 늘 띄워
## 두면 열한 칸이 전부 글자 벽이 되고, 아예 없애면 무엇을 사는지 모른다.
## 필요할 때만 나오는 것이 정답이다.
class _Cell extends Control:
	signal bought(id: String)

	const BASE_H: float = 76.0
	const OPEN_H: float = 110.0
	const CUT: float = 12.0

	var id: String = ""
	var level: int = 0
	var price: int = -1
	var affordable: bool = false
	var now: int = 0

	var _t: float = 0.0
	var _btn: Rect2 = Rect2()
	## 스크린샷 검증용. 마우스 없이 펼친 모습을 찍으려면 이 문이 필요하다.
	var forced: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(delta: float) -> void:
		var want: float = 1.0 if (forced or _inside()) else 0.0
		var k := clampf(delta * 12.0, 0.0, 1.0)
		var prev := _t
		_t = lerpf(_t, want, k)
		if absf(_t - prev) > 0.001:
			queue_redraw()

	func _inside() -> bool:
		return Rect2(Vector2.ZERO, Vector2(size.x, drawn_h())).has_point(
			get_local_mouse_position())

	func drawn_h() -> float:
		return lerpf(BASE_H, OPEN_H, _t)

	## 자란 부분까지 입력을 받아야 설명 위에서 손이 떨어지지 않는다.
	func _has_point(point: Vector2) -> bool:
		return Rect2(Vector2.ZERO, Vector2(size.x, drawn_h())).has_point(point)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed \
				and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if affordable and _btn.has_point((e as InputEventMouseButton).position):
				bought.emit(id)
				accept_event()

	func _draw() -> void:
		var d: Dictionary = Command.TABLE.get(id, {})
		var h := drawn_h()
		var s := Vector2(size.x, h)
		z_index = 4 if _t > 0.02 else 0
		var shape := PackedVector2Array([
			Vector2(CUT, 0), Vector2(s.x, 0), Vector2(s.x, s.y - CUT),
			Vector2(s.x - CUT, s.y), Vector2(0, s.y), Vector2(0, CUT),
		])
		draw_colored_polygon(shape, Color(0.05, 0.12, 0.19,
			lerpf(0.85, 0.98, _t)))
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		draw_polyline(line, Color(0.35, 0.75, 1.0, lerpf(0.30, 0.85, _t)), 1.6, true)
		# 홀로그램 주사선. 이 화면의 파란 톤을 유지한다.
		var sy := 0.0
		while sy < s.y:
			draw_line(Vector2(1, sy), Vector2(s.x - 1, sy), Color(0, 0, 0, 0.16), 1.0)
			sy += 3.0

		var fs := UiKit.font(12)
		draw_string(UiKit.font(13), Vector2(12, 20), String(d.get("name", id)),
			HORIZONTAL_ALIGNMENT_LEFT, int(s.x - 60), 13, UiKit.TEXT)
		if level > 0:
			draw_string(fs, Vector2(s.x - 56, 20), "+%d" % now,
				HORIZONTAL_ALIGNMENT_RIGHT, 46, 12, UiKit.GOOD)

		# 단계 칸. 산 만큼 채워진다 - 숫자보다 눈에 빨리 들어온다.
		for i in Command.MAX_LEVEL:
			var r := Rect2(12 + float(i) * 18.0, 32, 13, 11)
			draw_rect(r, Color(0.45, 0.85, 1.0) if i < level \
				else Color(0.11, 0.16, 0.22))
			draw_rect(r, Color(0.35, 0.75, 1.0, 0.45), false, 1.0)

		# 업그레이드 버튼. 칸 안에서 직접 그린다 - Button 을 얹으면 제 글자를
		# 먼저 그리고 그 위에 이 판이 덮인다(상점 슬래브에서 겪은 그것).
		var bw: float = minf(120.0, s.x - 86.0)
		_btn = Rect2(s.x - bw - 10.0, 28, bw, 20)
		var maxed := price < 0
		var bc: Color = Color(0.28, 0.34, 0.40)
		if not maxed:
			bc = Color(0.30, 0.70, 0.95) if affordable else Color(0.34, 0.30, 0.34)
		draw_rect(_btn, Color(bc.r, bc.g, bc.b, 0.22))
		draw_rect(_btn, Color(bc.r, bc.g, bc.b, 0.85), false, 1.0)
		var btxt := UiText.t("cmd.maxed_short", "최대") if maxed \
			else UiText.t("cmd.buy", "강화  -%d") % price
		draw_string(fs, Vector2(_btn.position.x, _btn.position.y + 14), btxt,
			HORIZONTAL_ALIGNMENT_CENTER, int(bw), 11,
			Color(0.75, 0.92, 1.0) if (affordable and not maxed) else UiKit.FAINT)

		# 펼쳐진 부분에만 설명을 적는다.
		if _t > 0.25:
			var a := clampf((_t - 0.25) / 0.5, 0.0, 1.0)
			var ty := 74.0
			for ln in _wrap(fs, String(d.get("text", "")), s.x - 24.0):
				if ty > s.y - 4.0:
					break
				draw_string(fs, Vector2(12, ty), ln,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.86, 0.96, a))
				ty += 15.0

	func _wrap(f: Font, text: String, max_w: float) -> Array:
		var out: Array = []
		var cur := ""
		for word in text.split(" "):
			var probe: String = word if cur == "" else cur + " " + word
			if f.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > max_w \
					and cur != "":
				out.append(cur)
				cur = word
			else:
				cur = probe
		if cur != "":
			out.append(cur)
		return out


## 실험용 장치의 모듈 한 줄. 축 색으로 왼쪽 막대를 세운다.
class _Swap extends Control:
	signal pressed_id(id: String)

	var id: String = ""
	var label: String = ""
	var tint: Color = Color(0.7, 0.7, 0.7)
	var enabled: bool = true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(_d: float) -> void:
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if enabled and e is InputEventMouseButton \
				and (e as InputEventMouseButton).pressed \
				and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			pressed_id.emit(id)
			accept_event()

	func _draw() -> void:
		var s := size
		var cut := 9.0
		var hot: bool = enabled and Rect2(Vector2.ZERO, s).has_point(
			get_local_mouse_position())
		var shape := PackedVector2Array([
			Vector2(cut, 0), Vector2(s.x, 0), Vector2(s.x, s.y - cut),
			Vector2(s.x - cut, s.y), Vector2(0, s.y), Vector2(0, cut),
		])
		draw_colored_polygon(shape, Color(0.06, 0.13, 0.20, 0.95 if hot else 0.8))
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		draw_polyline(line, Color(tint.r, tint.g, tint.b,
			(0.95 if hot else 0.45) if enabled else 0.2), 1.4, true)
		draw_rect(Rect2(0, cut, 3, s.y - cut),
			Color(tint.r, tint.g, tint.b, 0.9 if enabled else 0.25))
		draw_string(UiKit.font(12), Vector2(12, 20), label,
			HORIZONTAL_ALIGNMENT_LEFT, int(s.x - 50), 12,
			UiKit.TEXT if enabled else UiKit.FAINT)
		draw_string(UiKit.font(11), Vector2(s.x - 44, 20),
			"-%d" % Command.SWAP_COST, HORIZONTAL_ALIGNMENT_RIGHT, 36, 11,
			UiKit.ACCENT if enabled else UiKit.FAINT)
