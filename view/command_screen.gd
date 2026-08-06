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
	lbl_budget.text = UiText.t("shop.budget", "예산  %d") % run.budget

	# 10줄 + 분류 머리 4개 + 실험용 장치를 720 안에 다 넣어야 한다. 한 줄이라도
	# 아래로 밀리면 실험용 장치가 화면 밖으로 나간다 - 간격은 여유가 없다.
	var x := ART_W + 40.0
	var y := 92.0
	for group in Command.GROUPS:
		UiKit.label(root, Vector2(x, y), Vector2(300, 18), group, 13,
			Color(0.55, 0.88, 1.0))
		y += 20.0
		for id in Command.ids_in(group):
			_row(id, Vector2(x, y))
			y += 38.0
		y += 4.0

	_swap_section(Vector2(x, y + 4))


## 강화 한 줄. 이름 · 효과 · 단계 표시 · 구매 버튼.
func _row(id: String, at: Vector2) -> void:
	var d: Dictionary = Command.TABLE[id]
	var lv := run.command_level(id)
	var price := Command.price(lv)

	var panel := _Holo.new()
	panel.position = at
	panel.size = Vector2(700, 34)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	UiKit.label(panel, Vector2(12, 2), Vector2(150, 17), String(d["name"]), 13)
	UiKit.label(panel, Vector2(12, 18), Vector2(430, 15), String(d["text"]), 10, UiKit.MUTED)

	# 단계 칸. 산 만큼 채워진다 - 숫자보다 눈에 빨리 들어온다.
	for i in Command.MAX_LEVEL:
		var pip := ColorRect.new()
		pip.color = Color(0.45, 0.85, 1.0) if i < lv else Color(0.14, 0.18, 0.24)
		pip.position = Vector2(452 + i * 16, 13)
		pip.size = Vector2(11, 9)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(pip)

	# 지금 값이 얼마인지. 0단계면 안 적는다 - 아직 아무것도 아니기 때문이다.
	if lv > 0:
		UiKit.label(panel, Vector2(508, 10), Vector2(80, 16),
			"+%d" % Command.amount(id, lv), 12, UiKit.GOOD)

	var txt := UiText.t("cmd.maxed_short", "최대") if price < 0 \
		else UiText.t("cmd.buy", "강화  -%d") % price
	var btn := UiKit.button(panel, Vector2(578, 3), Vector2(110, 28), txt, 12)
	btn.disabled = price < 0 or run.budget < price
	btn.pressed.connect(func():
		var err := run.command_buy(id)
		lbl_note.text = err
		refresh()
	)


## ── 실험용 장치 ──────────────────────────────────────────────────────────
## 보유 모듈 하나를 같은 축의 다른 모듈로 바꾼다.
##
## 축을 넘어가면 안 된다. 표적을 위치로 바꿀 수 있으면 축의 의미가 사라진다.
## 축 안에서만 도니까 "표적 교리를 다듬는다" 가 된다.
func _swap_section(at: Vector2) -> void:
	UiKit.label(root, Vector2(at.x, at.y), Vector2(400, 20),
		UiText.t("cmd.swap_head", "실험용 장치"), 13, Color(0.55, 0.88, 1.0))
	UiKit.label(root, Vector2(at.x, at.y + 22), Vector2(700, 18),
		UiText.t("cmd.swap_sub", "보유 모듈 하나를 같은 축의 다른 모듈로 바꿉니다. 축은 넘어가지 않습니다."),
		10, UiKit.MUTED)

	if run.hand.is_empty():
		UiKit.label(root, Vector2(at.x, at.y + 44), Vector2(500, 18),
			UiText.t("cmd.swap_none", "보유 모듈이 없습니다."), 11, UiKit.FAINT)
		return

	# 한 줄만 놓는다. 두 줄이 되면 [상점으로] 를 밀어내고 화면 밖으로 나간다.
	# 대신 넘기는 버튼을 붙인다 - 4장만 보이고 나머지는 없는 셈 치면 안 된다.
	var owned: Array[String] = []
	for cid in run.hand:
		if Cards.TABLE.has(cid):
			owned.append(cid)
	var pages := int(ceil(owned.size() / 4.0))
	swap_page = 0 if pages == 0 else posmod(swap_page, pages)
	if pages > 1:
		var nx := UiKit.button(root, Vector2(at.x + 4 * 152, at.y + 44),
			Vector2(92, 28), UiText.t("cmd.swap_more", "다음 %d/%d") % [
				swap_page + 1, pages], 11)
		nx.pressed.connect(func():
			swap_page += 1
			refresh()
		)

	var i := 0
	for cid in owned.slice(swap_page * 4, swap_page * 4 + 4):
		var c: Dictionary = Cards.TABLE[cid]
		var ax := String(c.get("axis", ""))
		var btn := UiKit.button(root,
			Vector2(at.x + i * 152, at.y + 44),
			Vector2(146, 28), "%s  -%d" % [c["name"], Command.SWAP_COST], 11)
		btn.add_theme_color_override("font_color", Axes.color(ax))
		btn.disabled = run.budget < Command.SWAP_COST
		btn.pressed.connect(func():
			lbl_note.text = run.command_swap(cid)
			refresh()
		)
		i += 1


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
