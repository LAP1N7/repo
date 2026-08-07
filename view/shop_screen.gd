class_name ShopScreen
extends Control

## 1단계 - 덱 구성. 예산 안에서 규칙 카드를 사 모은다.
##
## 여기서 사기 카드가 통제된다. 예산이 하나뿐이라 강한 카드를 여러 장 사면
## 슬롯 9칸을 채울 값싼 카드가 모자란다.

signal done()
signal help()
signal command()

## 튜토리얼이 붙어 있으면 앵커를 등록하고 행동을 알린다. 없으면 전부 무시된다.
var tut: Tutorial = null

const SHOP_Y: float = 206.0
## 상점 카드(156~352)와 안내문(366) 아래.
const HAND_Y: float = 560.0

## 조작 버튼 줄의 y. 카드 아래끝(156+196=352)에서 넉넉히 띄운다.
## 카드는 호버하면 위로 떠오르므로 바짝 붙이면 손이 겹친다.
const BAR_Y: float = 440.0

var run: RunState

var lbl_budget: Label
var lbl_note: Label
var lbl_hint: Label
var lbl_strategy: Label
var btn_reroll: Button
var btn_refine: Button
var btn_merge: Button
var btn_command: Button
var sfx: Sfx
## 정제 모드: 손패 카드를 누르면 사는 게 아니라 영구히 버린다.
var refining: bool = false
var merging: bool = false
var btn_next: Button
var shop_root: Control
var hand_root: Control


func setup(p_run: RunState) -> void:
	run = p_run
	sfx = Sfx.new()
	add_child(sfx)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = UiKit.BG
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Arknights 계열의 인상은 장식이 아니라 **정렬**에서 온다. 얇은 가로선 하나가
	# 화면 위를 가로지르면 아래 요소가 전부 그 선에 맞춰 정렬된 것처럼 읽힌다.
	UiKit.frame(self, Axes.color(Axes.TARGET))

	UiKit.phase_header(self, Vector2(40, 20), 0)
	UiKit.label(self, Vector2(40, 60), Vector2(760, 22),
		UiText.t("shop.sub", "예산 안에서 규칙 카드를 산다. 산 카드만 유닛에게 꽂을 수 있다."), 13, UiKit.MUTED)

	lbl_budget = UiKit.label(self, Vector2(900, 26), Vector2(340, 34), "", 24, UiKit.ACCENT)
	lbl_budget.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# ── 스테이지 선택기는 뺐다 ───────────────────────────────────────────
	# 다섯 칸짜리 버튼 줄이 화면 위를 가로질렀는데, 런은 1부터 5까지 순서대로만
	# 간다. 고를 수 없는 것을 고를 수 있게 그려 놓으면 그 줄은 정보가 아니라
	# 소음이다. 지금 어느 판인지는 머리말이 이미 말하고 있다.
	#
	# 대신 그 자리를 적 정보에 준다. 적 알고리즘은 숨기지 않고 그대로 공개한다 -
	# 숨기면 시행착오 게임이 되고, 공개하면 추리 게임이 된다. (DESIGN 2.4)
	lbl_strategy = UiKit.label(self, Vector2(40, 90), Vector2(1000, 22), "", 13, UiKit.BAD)
	lbl_note = UiKit.label(self, Vector2(40, 116), Vector2(900, 22), "", 13, UiKit.MUTED)

	shop_root = Control.new()
	shop_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shop_root)

	hand_root = Control.new()
	hand_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand_root)

	# ── 조작 줄은 손패보다 **나중에** 만든다 ─────────────────────────────
	# 자식은 나중에 붙은 것이 위에 그려진다. 예전에는 버튼을 hand_root 보다
	# 먼저 만들어서, 손패가 늘어나면 카드가 버튼을 덮고 클릭까지 먹었다.
	# 만드는 순서 한 줄이 곧 레이어 순서다.
	var bar := Control.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	# 카드는 SHOP_Y(156)에서 시작해 높이 196 이므로 352 에서 끝난다.
	# 카드 아래 여백을 넉넉히 둬야 호버로 카드가 떠오를 때 버튼과 안 겹친다.
	btn_reroll = _slab(bar, Vector2(40, BAR_Y), Vector2(236, 54), "", UiKit.TEXT)
	btn_reroll.pressed.connect(_on_reroll)

	btn_refine = _slab(bar, Vector2(288, BAR_Y), Vector2(236, 54), "", UiKit.TEXT)
	btn_refine.pressed.connect(_on_refine_toggle)

	# 합성은 축 개편에서 빠졌다. 자리를 되살릴 계획(환전·교환)이 있으므로
	# 노드는 남기고 보이지만 않게 한다. 지우면 배치를 다시 잡아야 한다.
	btn_merge = _slab(bar, Vector2(784, BAR_Y), Vector2(236, 54), "", UiKit.GOOD)
	btn_merge.pressed.connect(_on_merge_toggle)
	btn_merge.visible = false
	btn_merge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 보조 지휘는 정제 옆이다. 셋 다 "예산을 어디에 쓸까" 라서, 재검색·정제와
	# 나란히 놓여야 같은 저울에 올려놓고 고르게 된다.
	btn_command = _slab(bar, Vector2(536, BAR_Y), Vector2(236, 54),
		UiText.t("shop.command", "보조 지휘  →"), Color(0.55, 0.88, 1.0))
	btn_command.pressed.connect(func():
		sfx.play("click")
		command.emit()
	)

	lbl_hint = UiKit.label(bar, Vector2(40, BAR_Y + 62), Vector2(1000, 22),
		"", 12, UiKit.MUTED)

	btn_next = _slab(self, Vector2(960, 636), Vector2(280, 60),
		UiText.t("shop.next", "편성 단계로  ▶"), UiKit.ACCENT, 19)
	btn_next.pressed.connect(func():
		if tut != null:
			tut.notify_action("next")
		done.emit()
	)
	if tut != null:
		tut.register_anchor("shop_reroll", btn_reroll)
		tut.register_anchor("shop_next", btn_next)

	refresh()


func refresh() -> void:
	# 가산금과 리롤값은 이번 스테이지에 산 만큼 오른다. 값이 왜 올랐는지
	# 화면에 안 적히면 "버그인가?" 가 된다.
	var sur := run.surcharge()
	lbl_budget.text = UiText.t("shop.budget", "예산  %d") % run.budget
	if sur > 0:
		# 자리 표시 개수와 인자 개수가 반드시 같아야 한다. 하나라도 어긋나면
		# 치환이 통째로 실패해 "%d" 가 화면에 그대로 뜬다.
		lbl_budget.text += UiText.t("shop.budget_surcharge", "  (+%d)") % sur
	# 제외권이 몇 장 남았는지 안내문에 적는다. 카드마다 숫자가 붙지만,
	# 지금 몇 장인지를 한 곳에서도 말해 줘야 "쓸까 말까" 를 결정할 수 있다.
	lbl_hint.text = UiText.t("shop.hint",
		"카드를 누르면 구매.  [제외] 는 그 모듈을 작전 전체에서 없앤다 - 정제권을 1장 쓴다 (%d장)") 		% run.refine_tokens
	btn_reroll.disabled = not run.can_reroll()
	btn_reroll.set_label(UiText.t("shop.reroll", "재검색  (-%d)") % run.reroll_cost())

	# ── 다음 판이 어떤 판인지 한 줄로 다 말한다 ──────────────────────────
	# 편성을 짜기 전에 알아야 할 것은 "이 판이 무엇을 요구하는가" 하나다.
	# 적 알고리즘 · 페이즈 수 · 지형 기믹 · 등장 특성을 한 줄에 모은다.
	# 나눠 놓으면 읽는 순서가 정해지지 않아서 결국 아무도 안 읽는다.
	var st := Stages.get_stage(run.stage_id)
	var line := UiText.t("shop.enemy_strategy", "적 전략:  %s") % st["strategy_text"]
	var waves: int = Stages.waves(st).size()
	if waves > 1:
		line += UiText.t("shop.waves", "     %d 페이즈") % waves
	var hz := Stages.hazard(run.stage_id)
	if not hz.is_empty():
		line += UiText.t("shop.hazard", "     %s") % String(hz.get("name", ""))
	for t in Stages.trait_list(run.stage_id):
		line += "     " + Traits.describe(t).split(" - ")[0]
	lbl_strategy.text = line

	# 정제권이 없으면 정제 모드로 들어갈 수 없다.
	if run.refine_tokens <= 0:
		refining = false
	btn_refine.disabled = run.refine_tokens <= 0 		or (run.hand.is_empty() and run.special_hand.is_empty())
	btn_refine.set_label(
		UiText.t("shop.refine", "알고리즘 정제  (%d)") % run.refine_tokens,
		UiKit.BAD if refining else UiKit.TEXT)

	# 합성 가능한 카드가 하나라도 있어야 켜진다.
	var mergeable := 0
	for cid in run.hand:
		if run.can_merge(String(cid)):
			mergeable += 1
	if mergeable == 0:
		merging = false
	btn_merge.disabled = mergeable == 0
	btn_merge.set_label(
		UiText.t("shop.merge", "모듈 합성  (%d)") % mergeable,
		Color(1, 1, 1) if merging else UiKit.GOOD)

	_build_shop()
	_build_hand()

	var n := run.hand.size() + run.special_hand.size()
	if n == 0:
		lbl_note.text = UiText.t("shop.empty_hand", "아직 산 카드가 없다. 카드가 없으면 유닛은 직업 기본기만으로 싸운다.")
		lbl_note.add_theme_color_override("font_color", UiKit.MUTED)
	else:
		lbl_note.text = UiText.t("shop.hand_summary", "손패 %d장 (특수 %d) · 사용한 예산 %d") % [
			n, run.special_hand.size(), run.spent()]
		lbl_note.add_theme_color_override("font_color", UiKit.GOOD if n >= 3 else UiKit.MUTED)

	# 손패 장수로 진행을 막지 않는다.
	# 예전에는 3장 미만이면 막았는데, 코스트 0 카드(사수)가 1코가 되면서
	# "예산을 리롤로 다 태우고 손패가 2장" 이면 되돌릴 방법이 없는 소프트락이 됐다.
	# 기본기가 있으니 빈손으로도 전투는 성립한다. 막을 이유가 없다.
	btn_next.disabled = false


func _build_shop() -> void:
	for c in shop_root.get_children():
		c.queue_free()

	var total := run.offers.size()
	var gap := 18.0
	var w := CardNode.W
	var span := total * w + (total - 1) * gap
	var x0 := (1280.0 - span) * 0.5

	# 보유 모듈로 한 장만 더 채우면 켜지는 교리들. { 모듈 id: 교리 이름 }
	var near: Dictionary = {}
	# 손패만 보면 안 된다. 이미 대원에게 장착한 모듈은 손패에서 빠져 있어서,
	# 한 장 남은 교리가 있어도 "완성" 안내가 안 떴다. 보유 + 장착을 다 센다.
	var owned: Array = []
	owned.append_array(run.hand)
	for row in run.unit_cards:
		owned.append_array(row)
	for n in Doctrines.near_complete(owned):
		near[String(n["need"])] = String((n["doctrine"] as Dictionary)["name"])

	for i in total:
		var cid: String = run.offers[i]
		var card := CardNode.new()
		shop_root.add_child(card)
		card.setup(cid, i, false, cid != "", run.refine_tokens)
		card.enabled = run.can_buy(i)
		if cid != "" and not run.can_buy(i):
			card.note = UiText.t("shop.note_poor", "예산 부족 (%d)") % run.price_of(cid)
		elif cid != "" and near.has(cid):
			# ── 교리 완성 안내 ────────────────────────────────────────────
			# 이 게임은 모듈을 모으는 게 아니라 교리를 완성하는 게임이다.
			# 완성까지 한 장 남았다는 사실이 안 보이면 그 재미가 통째로 사라진다.
			card.note = UiText.t("shop.note_doctrine", "%s 완성") % near[cid]
		card.place(Vector2(x0 + i * (w + gap), SHOP_Y))
		card.clicked.connect(_on_buy)
		card.banned.connect(_on_ban)
		if tut != null:
			tut.register_anchor("shop_card_%d" % i, card)
			if card.get_child_count() > 0 and card.get_child(0) is Button:
				tut.register_anchor("shop_ban_%d" % i, card.get_child(0))


## 손패는 발라트로처럼 부채꼴로 겹쳐 깐다. 장수가 늘면 자동으로 더 겹친다.
## ── 사선으로 깎은 큰 버튼 ────────────────────────────────────────────────
## 명일방주 계열의 조작 단추는 크고 각졌다. 작은 회색 상자를 여러 개 늘어놓으면
## 무엇이 중요한지 알 수 없고, 무엇보다 **누를 것이 있다는 사실 자체**가 눈에
## 안 들어온다.
##
## 전투 화면에서 대원 얼굴을 호버하면 뜨는 판과 같은 어법이다 - 왼쪽 위와
## 오른쪽 아래를 깎고, 왼쪽에 색 막대를 세운다. 화면끼리 같은 모양을 쓰면
## 하나의 물건으로 읽힌다.
func _slab(parent: Node, at: Vector2, sz: Vector2, text: String,
		tint: Color, fsize: int = 15) -> Button:
	var b := _Slab.new()
	b.position = at
	b.size = sz
	b.tint = tint
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var blank := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, blank)
	parent.add_child(b)

	# ── 글자는 자식 노드로 ───────────────────────────────────────────────
	# Button 이 제 글자를 먼저 그리고 그 위에 _draw() 가 얹힌다. 그래서 판을
	# 직접 그리면 글자가 통째로 덮인다 - 편성 얼굴 타일에서 겪은 것과 같다.
	var l := Label.new()
	l.text = text
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UiKit.font(fsize))
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", tint)
	b.add_child(l)
	b.label = l
	return b


class _Slab extends Button:
	var tint: Color = UiKit.TEXT
	var label: Label

	## 글자와 색을 한 번에 바꾼다. text 속성을 직접 건드리면 자식 라벨과
	## 어긋나므로 이 함수만 쓴다.
	func set_label(t: String, col: Color = Color(0, 0, 0, 0)) -> void:
		if label == null:
			return
		label.text = t
		if col.a > 0.0:
			tint = col
		label.add_theme_color_override("font_color",
			Color(0.42, 0.44, 0.50) if disabled else tint)
		queue_redraw()

	func _process(_d: float) -> void:
		queue_redraw()

	const CUT: float = 13.0

	func _draw() -> void:
		var s := size
		var on := is_hovered() and not disabled
		var shape := PackedVector2Array([
			Vector2(CUT, 0), Vector2(s.x, 0), Vector2(s.x, s.y - CUT),
			Vector2(s.x - CUT, s.y), Vector2(0, s.y), Vector2(0, CUT),
		])
		var body := Color(0.12, 0.135, 0.17) if not disabled else Color(0.075, 0.08, 0.10)
		if on:
			body = Color(0.17, 0.19, 0.24)
		draw_colored_polygon(shape, body)
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		var a: float = 0.20 if disabled else (0.95 if on else 0.55)
		draw_polyline(line, Color(tint.r, tint.g, tint.b, a), 2.0, true)
		# 왼쪽 색 막대. 글자를 안 읽어도 무슨 종류의 단추인지 색으로 갈린다.
		if not disabled:
			draw_rect(Rect2(0, CUT, 4, s.y - CUT), Color(tint.r, tint.g, tint.b, a))


func _build_hand() -> void:
	for c in hand_root.get_children():
		c.queue_free()

	# 규칙 카드와 특수 스킬을 한 줄에 같이 깐다. 둘 다 "산 것" 이고,
	# 어느 유닛에 무엇을 꽂을지는 2단계에서 정한다.
	var owned: Array[String] = []
	for cid in run.hand:
		owned.append(cid)
	for sid in run.special_hand:
		owned.append(sid)

	# ── 보유 모듈은 오른쪽 서류첩에 꽂아 둔다 ────────────────────────────
	# 화면 아래 절반을 손패가 통째로 쓰고 있었다. 그런데 이 화면에서 하는 일은
	# **사는 것**이고, 산 것을 다시 보는 일은 그보다 훨씬 드물다. 드문 것이
	# 넓은 자리를 차지하면 잦은 것이 좁아진다.
	#
	# 옆에 세워 두고, 손을 올리면 펼쳐진다. 서류첩에서 서류를 꺼내 보는 것과
	# 같은 동작이라 설명이 필요 없다.
	var n := owned.size()
	var tab := _Dossier.new()
	tab.position = Vector2(1180 + 56 - _Dossier.TAB_W, SHOP_Y)
	tab.size = Vector2(_Dossier.TAB_W, 288)
	# 카드보다 위에 떠야 서랍이 카드에 잘리지 않는다.
	tab.z_index = 40
	tab.top_level = false
	tab.count = n
	tab.special_n = run.special_hand.size()
	var names: Array = []
	for cid in owned:
		var t: Dictionary = Cards.TABLE.get(cid, Specials.TABLE.get(cid, {}))
		names.append(String(t.get("name", cid)))
	tab.view_names = names
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab.clip_contents = false
	hand_root.add_child(tab)

	var head_col := UiKit.TEXT
	var head := ""
	if refining:
		head = UiText.t("shop.hand_refining", "버릴 모듈을 누르십시오 (정제권 %d)") % run.refine_tokens
		head_col = UiKit.BAD
	elif merging:
		head = UiText.t("shop.hand_merging", "같은 모듈 2장을 1장으로 합쳐 한 단계 올립니다")
		head_col = UiKit.GOOD
	if head != "":
		UiKit.label(hand_root, Vector2(40, HAND_Y - 34), Vector2(900, 24), head, 15, head_col)

	if n == 0:
		return
	# 평소에는 서류첩만 보인다. 펼쳐야 할 이유가 있을 때만 카드를 깐다.
	if not (refining or merging):
		return

	var mini_w := CardNode.W * 0.72
	var max_span := 1000.0
	var step: float = minf(mini_w + 12.0, (max_span - mini_w) / maxf(1.0, float(n - 1)))
	var span := mini_w + step * (n - 1)
	var x0 := (1280.0 - span) * 0.5
	var mid := (n - 1) * 0.5

	for i in n:
		var card := CardNode.new()
		hand_root.add_child(card)
		card.setup(owned[i], i, true, false)
		card.level = run.card_level(String(owned[i]))
		# 평소 손패는 보기 전용이다(장착은 2단계). 정제·합성 모드에서만 눌린다.
		card.enabled = refining or (merging and run.can_merge(String(owned[i])))
		if refining:
			card.note = UiText.t("shop.note_discard", "누르면 버림")
			card.clicked.connect(_on_hand_refine)
		elif merging:
			var cid2 := String(owned[i])
			if run.can_merge(cid2):
				card.note = UiText.t("shop.note_merge", "합성 -%d") % run.merge_price(cid2)
				card.clicked.connect(_on_hand_merge)
			else:
				card.note = run.merge_blocker(cid2)
		var offset := float(i) - mid
		# 가운데가 높고 양끝이 낮은 아치
		var arc := absf(offset) * 3.0
		card.place(Vector2(x0 + i * step, HAND_Y + arc), offset * 0.02)


## ── 보유 모듈 서류첩 ─────────────────────────────────────────────────────
## 오른쪽에 세워 둔 세로 탭. 손을 올리면 왼쪽으로 서랍이 밀려 나온다.
##
## 평소에는 "몇 장 들고 있다" 만 알면 되고, 무엇을 들고 있는지는 편성 화면에서
## 어차피 다시 본다. 그래서 기본은 닫힌 상태다 - 자주 하는 일(사기)에 넓은
## 자리를 주고, 드문 일(확인)은 손을 뻗어야 열리게 한다.
class _Dossier extends Control:
	const TAB_W: float = 56.0
	const OPEN_W: float = 320.0
	const CUT: float = 14.0

	var count: int = 0
	var special_n: int = 0
	var view_names: Array = []

	var _open: float = 0.0
	var _forced: bool = false

	## 스크린샷 검증용. 마우스 없이 펼친 모습을 찍으려면 이 문이 필요하다.
	func force_open() -> void:
		_forced = true

	## 서랍이 열리면 판이 제 Control 사각형 왼쪽으로 삐져나간다. 그 위에
	## 마우스가 올라가 있는 동안에도 열린 채여야 하므로, 판정은 rect 가 아니라
	## 실제로 그려진 넓이로 한다.
	func _drawn_rect() -> Rect2:
		var w := TAB_W + _open * OPEN_W
		return Rect2(Vector2(size.x - w, 0), Vector2(w, size.y))

	func _process(delta: float) -> void:
		var want := 0.0
		if _forced or _drawn_rect().has_point(get_local_mouse_position()):
			want = 1.0
		_open = lerpf(_open, want, clampf(delta * 10.0, 0.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		var s := size
		var r := _drawn_rect()
		var x0 := r.position.x
		var shape := PackedVector2Array([
			Vector2(x0 + CUT, 0), Vector2(s.x, 0), Vector2(s.x, s.y),
			Vector2(x0 + CUT, s.y), Vector2(x0, s.y - CUT), Vector2(x0, CUT),
		])
		draw_colored_polygon(shape, Color(0.075, 0.09, 0.125, 0.985))
		var line := PackedVector2Array(shape)
		line.append(shape[0])
		draw_polyline(line, Color(0.42, 0.62, 0.80, 0.75), 2.0, true)

		var fs := UiKit.font(12)
		# 탭 기둥. 열려도 이 칸은 그대로 남아서 "여기가 손잡이" 를 유지한다.
		var col := s.x - TAB_W
		draw_line(Vector2(col, 6), Vector2(col, s.y - 6),
			Color(0.42, 0.62, 0.80, 0.30 * _open), 1.0)
		var label := UiText.t("shop.dossier", "보유")
		for i in label.length():
			draw_string(fs, Vector2(col + 21, 26.0 + float(i) * 18.0),
				label[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.MUTED)
		draw_string(UiKit.font(20), Vector2(col + 16, s.y - 40), str(count),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiKit.ACCENT)
		if special_n > 0:
			draw_string(fs, Vector2(col + 16, s.y - 20), "+%d" % special_n,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.74, 0.20))
		# 닫힌 상태의 서류철 무늬. 가로줄 몇 개면 "안에 종이가 꽂혀 있다" 로
		# 읽힌다. 켜진 줄 수가 들고 있는 장수다.
		var mark := 1.0 - _open
		if mark > 0.02:
			for i in 8:
				var y := 68.0 + float(i) * 20.0
				if y > s.y - 60.0:
					break
				var lit: bool = i < count
				draw_rect(Rect2(col + 12, y, TAB_W - 24, 3), Color(0.45, 0.70, 0.92,
					(0.62 if lit else 0.13) * mark))

		# 펼쳐지면 꽂힌 모듈을 한 줄씩 적는다. 카드를 다시 그리기에는 좁고,
		# 여기서 하려는 일은 "무엇을 들고 있더라" 를 훑는 것뿐이다.
		var a: float = clampf((_open - 0.35) / 0.5, 0.0, 1.0)
		if a <= 0.01:
			return
		draw_string(fs, Vector2(x0 + 18, 30),
			UiText.t("shop.dossier_head", "보유 모듈"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.52, 0.68, 0.85, a))
		for i in view_names.size():
			var y2 := 56.0 + float(i) * 24.0
			if y2 > s.y - 16.0:
				break
			draw_rect(Rect2(x0 + 18, y2 - 13, 3, 15), Color(0.45, 0.70, 0.92, a * 0.8))
			draw_string(UiKit.font(13), Vector2(x0 + 28, y2), String(view_names[i]),
				HORIZONTAL_ALIGNMENT_LEFT, int(OPEN_W - 46), 13,
				Color(0.88, 0.92, 0.97, a))


func _on_merge_toggle() -> void:
	merging = not merging
	if merging:
		refining = false
	refresh()


func _on_hand_merge(card: CardNode) -> void:
	if run.merge(card.card_id):
		sfx.play("special")
		refresh()


func _on_buy(card: CardNode) -> void:
	if run.buy(card.index):
		sfx.play("buy")
		if tut != null:
			tut.notify_action("buy")
		refresh()


func _on_ban(card: CardNode) -> void:
	if run.ban(card.index):
		if tut != null:
			tut.notify_action("ban")
		refresh()


## 정제 = 손패에서 카드를 영구히 버린다.
##
## 덱이 두꺼워질수록 원하는 카드가 뽑힐 확률이 떨어진다. 정제는 그걸 되돌리는
## 유일한 수단이고, 정제권은 보상에서만 나온다. 상시 무료로 열어두면 누구나
## 덱을 최적으로 깎아서 오히려 빌드가 획일화된다.
func _on_refine_toggle() -> void:
	refining = not refining
	if refining:
		merging = false
	refresh()


func _on_hand_refine(card: CardNode) -> void:
	if run.refine(card.card_id):
		refresh()


func _on_reroll() -> void:
	if run.reroll():
		sfx.play("click")
		refresh()
