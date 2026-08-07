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
## 이 판에 나오는 적 구성. 대응 모듈을 고를 근거다.
var lbl_roster: Label
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
	lbl_roster = UiKit.label(self, Vector2(40, 112), Vector2(1100, 20), "", 12,
		Color(0.92, 0.62, 0.58))
	lbl_note = UiKit.label(self, Vector2(40, 134), Vector2(900, 22), "", 13, UiKit.MUTED)

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
	if tut != null:
		tut.register_anchor("shop_command", btn_command)

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
	# ── 무엇이 오는지 ────────────────────────────────────────────────────
	# 여기가 모듈을 사는 자리다. 그런데 사는 시점에 적 구성을 모르면 [지원
	# 차단]·[사수 사냥]·[방패 격파] 같은 대응 모듈은 전부 도박이 된다.
	# 공개하면 그 자리에서 답이 보이고, 그게 이 게임이 판마다 새 답을 요구하는
	# 방식이다.
	lbl_roster.text = UiText.t("shop.enemy_roster", "적 구성:  %s") % 		Stages.enemy_summary(run.stage_id)

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
	# rect 는 서랍을 다 편 크기로 잡는다. 안 그러면 펼쳐진 부분의 클릭·휠이
	# Control 밖이라 이벤트가 오지 않는다. 닫혀 있을 때 뒤를 안 먹는 것은
	# _has_point 가 막는다.
	tab.position = Vector2(1240 - _Dossier.TAB_W - _Dossier.OPEN_W, SHOP_Y - 16)
	tab.size = Vector2(_Dossier.TAB_W + _Dossier.OPEN_W, 368)
	# 카드보다 위에 떠야 서랍이 카드에 잘리지 않는다.
	tab.z_index = 40
	tab.top_level = false
	tab.count = n
	tab.special_n = run.special_hand.size()
	tab.view_ids = owned.duplicate()
	# 휠 스크롤과 분류 탭 클릭을 받아야 한다. IGNORE 면 서랍이 아무 입력도
	# 못 받는다.
	tab.mouse_filter = Control.MOUSE_FILTER_STOP
	tab.clip_contents = false

	# ── 뒤를 덮는 판 ────────────────────────────────────────────────────
	# 서랍이 열리면 그 아래 상점 카드가 마우스를 먹고 튀어 오른다. 카드가
	# 판 위로 떠오르니 무엇이 앞인지 알 수 없고, 잘못 누르면 사 버린다.
	# 어둡게 덮고 입력도 막는다. 탭보다 먼저 붙여야 탭이 위에 남는다.
	var shield := ColorRect.new()
	shield.color = Color(0.02, 0.03, 0.05, 0.62)
	shield.position = Vector2.ZERO
	shield.size = Vector2(1280, 720)
	shield.z_index = 30
	shield.visible = false
	shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_root.add_child(shield)
	tab.shield = shield

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
##
## 이름 위에 한 번 더 손을 올리면 카드 원본이 옆에 뜬다. 이름만으로는 "이게
## 무슨 조건이었더라" 가 안 풀리는데, 그걸 확인하려고 편성 화면까지 갔다
## 오게 만들면 사는 흐름이 끊긴다.
##
## ── 열려 있는 동안 뒤는 잠근다 ──────────────────────────────────────────
## 서랍이 상점 카드 위를 덮는데, 그 아래 카드가 마우스를 먹고 튀어 올랐다.
## 판 위로 카드가 떠오르니 무엇이 앞인지 알 수 없고, 잘못 누르면 사 버린다.
## 열려 있는 동안은 뒤를 어둡게 덮고 입력도 막는다.
class _Dossier extends Control:
	const TAB_W: float = 60.0
	const OPEN_W: float = 430.0
	const CUT: float = 16.0
	const ROW_H: float = 34.0
	const ROW_TOP: float = 96.0
	const NAME_SIZE: int = 17
	const TAB_H: float = 30.0

	## 분류 탭. 순서는 판단 순서(표적 -> 위치 -> 교전)와 같다.
	const FILTERS: Array = ["all", Axes.TARGET, Axes.POSITION, Axes.DOCTRINE, "ult"]

	var count: int = 0
	var special_n: int = 0
	var view_ids: Array = []

	## 서랍이 열렸을 때 뒤를 덮는 판. 화면 전체를 먹는다.
	var shield: Control = null

	var _open: float = 0.0
	var _forced: bool = false
	var _hot: int = -1
	var _peek: CardNode = null
	var _filter: int = 0
	var _scroll: float = 0.0
	var _hot_tab: int = -1

	## 스크린샷 검증용. 마우스 없이 펼친 모습을 찍으려면 이 문이 필요하다.
	func force_open(row: int = -1, filter: int = 0) -> void:
		_forced = true
		_hot = row
		_filter = filter
		# 검수 스크립트는 프레임을 최대 속도로 돌려서 delta 가 아주 작다. 보간을
		# 기다리면 반쯤 열린 상태가 찍힌다. 곧바로 다 연 상태로 둔다.
		_open = 1.0

	## 지금 분류에 걸리는 것만. 표시도 스크롤도 전부 이 목록 기준이다.
	func shown() -> Array:
		var f: String = String(FILTERS[_filter])
		if f == "all":
			return view_ids
		var out: Array = []
		for cid in view_ids:
			var id := String(cid)
			if f == "ult":
				if RunState.is_special(id):
					out.append(id)
			elif not RunState.is_special(id) \
					and String(Cards.TABLE.get(id, {}).get("axis", "")) == f:
				out.append(id)
		return out

	## 한 번에 보이는 줄 수.
	func rows_fit() -> int:
		return maxi(1, int((size.y - ROW_TOP - 8.0) / ROW_H))

	func max_scroll() -> float:
		return maxf(0.0, float(shown().size() - rows_fit()))

	## 입력을 받을 넓이. rect 는 다 편 크기로 잡혀 있으므로, 닫혀 있을 때
	## 이걸로 좁혀 주지 않으면 손잡이 왼쪽의 상점 카드가 전부 안 눌린다.
	func _has_point(point: Vector2) -> bool:
		return _drawn_rect().has_point(point)

	## 지금 그려져 있는 넓이. 열리면 왼쪽으로 자란다.
	func _drawn_rect() -> Rect2:
		var w := TAB_W + _open * OPEN_W
		return Rect2(Vector2(size.x - w, 0), Vector2(w, size.y))

	func _gui_input(e: InputEvent) -> void:
		if _open < 0.5:
			return
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			var mb := e as InputEventMouseButton
			match mb.button_index:
				MOUSE_BUTTON_WHEEL_DOWN:
					_scroll = minf(max_scroll(), _scroll + 1.0)
					accept_event()
				MOUSE_BUTTON_WHEEL_UP:
					_scroll = maxf(0.0, _scroll - 1.0)
					accept_event()
				MOUSE_BUTTON_LEFT:
					var t := _tab_at(mb.position)
					if t >= 0:
						_filter = t
						_scroll = 0.0
						accept_event()

	## 좌표가 어느 분류 탭 위인가. -1 이면 어느 쪽도 아니다.
	func _tab_at(m: Vector2) -> int:
		var x0 := _drawn_rect().position.x
		if m.y < 46.0 or m.y > 46.0 + TAB_H:
			return -1
		var tw := (OPEN_W - 36.0) / float(FILTERS.size())
		var i := int((m.x - (x0 + 18.0)) / tw)
		return i if i >= 0 and i < FILTERS.size() else -1

	func _process(delta: float) -> void:
		var m := get_local_mouse_position()
		var inside := _drawn_rect().has_point(m)
		var want: float = 1.0 if (_forced or inside) else 0.0
		_open = lerpf(_open, want, clampf(delta * 10.0, 0.0, 1.0))
		if shield != null and is_instance_valid(shield):
			shield.visible = _open > 0.02
			shield.modulate.a = clampf(_open * 1.2, 0.0, 1.0)
			shield.mouse_filter = Control.MOUSE_FILTER_STOP if _open > 0.35 \
				else Control.MOUSE_FILTER_IGNORE

		_scroll = clampf(_scroll, 0.0, max_scroll())
		_hot_tab = _tab_at(m) if inside and _open > 0.85 else -1

		# 어느 줄에 손이 올라가 있는가. 서랍이 거의 다 열린 뒤에만 센다 -
		# 열리는 도중에 줄이 스쳐 지나가면 카드가 깜빡거린다.
		if not _forced:
			_hot = -1
			if inside and _open > 0.85 and m.x < size.x - TAB_W and m.y >= ROW_TOP - 20.0:
				var r := int(floor((m.y - ROW_TOP + ROW_H * 0.5) / ROW_H)) + int(_scroll)
				if r >= 0 and r < shown().size():
					_hot = r
		_sync_peek()
		queue_redraw()

	## 짚은 줄의 카드 원본을 서랍 왼쪽에 세운다.
	func _sync_peek() -> void:
		var list := shown()
		var want_id := ""
		if _hot >= 0 and _hot < list.size() and _open > 0.85:
			want_id = String(list[_hot])
		if want_id == "":
			if _peek != null:
				_peek.queue_free()
				_peek = null
			return
		if _peek != null and _peek.card_id == want_id:
			return
		if _peek != null:
			_peek.queue_free()
		var c := CardNode.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.z_index = 6
		add_child(c)
		c.setup(want_id, 0)
		c.enabled = true
		# 카드가 서랍 왼쪽에 붙되 칸 위아래를 넘지 않게 잡는다.
		var y := clampf(ROW_TOP + (float(_hot) - _scroll) * ROW_H - CardNode.H * 0.5,
			0.0, maxf(0.0, size.y - CardNode.H))
		c.place(Vector2(size.x - TAB_W - OPEN_W - CardNode.W - 12.0, y))
		_peek = c

	func _draw() -> void:
		var s := size
		var r := _drawn_rect()
		var x0 := r.position.x
		var shape := PackedVector2Array([
			Vector2(x0 + CUT, 0), Vector2(s.x, 0), Vector2(s.x, s.y),
			Vector2(x0 + CUT, s.y), Vector2(x0, s.y - CUT), Vector2(x0, CUT),
		])
		draw_colored_polygon(shape, Color(0.075, 0.09, 0.125, 1.0))
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
			draw_string(fs, Vector2(col + 23, 26.0 + float(i) * 18.0),
				label[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.MUTED)
		draw_string(UiKit.font(22), Vector2(col + 18, s.y - 40), str(count),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.ACCENT)
		if special_n > 0:
			draw_string(fs, Vector2(col + 18, s.y - 20), "+%d" % special_n,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.74, 0.20))
		# 닫힌 상태의 서류철 무늬. 가로줄 몇 개면 "안에 종이가 꽂혀 있다" 로
		# 읽힌다. 켜진 줄 수가 들고 있는 장수다.
		var mark := 1.0 - _open
		if mark > 0.02:
			for i in 9:
				var y := 66.0 + float(i) * 20.0
				if y > s.y - 62.0:
					break
				var lit: bool = i < count
				draw_rect(Rect2(col + 13, y, TAB_W - 26, 3), Color(0.45, 0.70, 0.92,
					(0.62 if lit else 0.13) * mark))

		var a: float = clampf((_open - 0.35) / 0.5, 0.0, 1.0)
		if a <= 0.01:
			return
		var list := shown()
		draw_string(fs, Vector2(x0 + 20, 30),
			UiText.t("shop.dossier_head", "보유 모듈"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.52, 0.68, 0.85, a))

		# ── 분류 탭 ──────────────────────────────────────────────────────
		# 아홉 장이 넘어가면 이름만 늘어놓아서는 "위치 모듈이 몇 장이더라" 가
		# 안 잡힌다. 축이 곧 이 게임의 문법이므로 축으로 가른다.
		var tw := (OPEN_W - 36.0) / float(FILTERS.size())
		for i in FILTERS.size():
			var f := String(FILTERS[i])
			var tx := x0 + 18.0 + float(i) * tw
			var on: bool = i == _filter
			var tc: Color = UiKit.MUTED
			var nm := UiText.t("shop.filter_all", "전체")
			if f == "ult":
				tc = Color(1.0, 0.74, 0.20)
				nm = "ULT"
			elif f != "all":
				tc = Axes.color(f)
				nm = Axes.label(f)
			if on:
				draw_rect(Rect2(tx, 46, tw - 4, TAB_H),
					Color(tc.r, tc.g, tc.b, 0.22 * a))
			elif i == _hot_tab:
				draw_rect(Rect2(tx, 46, tw - 4, TAB_H), Color(1, 1, 1, 0.07 * a))
			draw_rect(Rect2(tx, 46 + TAB_H - 2, tw - 4, 2),
				Color(tc.r, tc.g, tc.b, (0.95 if on else 0.20) * a))
			draw_string(fs, Vector2(tx, 46 + 20), nm,
				HORIZONTAL_ALIGNMENT_CENTER, int(tw - 4), 11,
				Color(tc.r, tc.g, tc.b, a) if on else Color(0.62, 0.68, 0.76, a))

		# 탭 기둥을 침범하면 줄 강조가 손잡이까지 덮어서 어디까지가 서랍인지
		# 안 보인다. 내용은 기둥 왼쪽에서 끝난다.
		var inner := OPEN_W - 40.0
		if list.is_empty():
			draw_string(fs, Vector2(x0 + 28, ROW_TOP),
				UiText.t("shop.dossier_none", "이 분류에는 없습니다"),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.55, 0.58, 0.65, a))
			return

		var nf := UiKit.font(NAME_SIZE)
		var first := int(_scroll)
		var fit := rows_fit()
		for k in fit:
			var i2 := first + k
			if i2 >= list.size():
				break
			var y2 := ROW_TOP + float(k) * ROW_H
			var cid := String(list[i2])
			var sp := RunState.is_special(cid)
			var t: Dictionary = Specials.TABLE.get(cid, {}) if sp \
				else Cards.TABLE.get(cid, {})
			var hot: bool = i2 == _hot
			if hot:
				draw_rect(Rect2(x0 + 12, y2 - 22, inner, ROW_H - 4),
					Color(0.30, 0.52, 0.72, 0.30 * a))
			var bar: Color = Color(1.0, 0.74, 0.20) if sp else Color(0.45, 0.70, 0.92)
			draw_rect(Rect2(x0 + 16, y2 - 19, 4, 20),
				Color(bar.r, bar.g, bar.b, a * (1.0 if hot else 0.75)))
			draw_string(nf, Vector2(x0 + 28, y2), String(t.get("name", cid)),
				HORIZONTAL_ALIGNMENT_LEFT, int(inner - 96.0), NAME_SIZE,
				Color(1, 1, 1, a) if hot else Color(0.86, 0.90, 0.96, a))
			# 오른쪽에 종류를 붙인다. 셋을 고루 들었는지 훑는 데 쓴다.
			# 궁극기는 축이 없다 - 축 칸을 비워 두면 "분류를 못 받은 것" 처럼
			# 보이므로 ULTIMATE 라고 적는다.
			var tag := ""
			var tc2: Color = UiKit.MUTED
			if sp:
				tag = "ULTIMATE"
				tc2 = Color(1.0, 0.74, 0.20)
			else:
				var ax := String(t.get("axis", ""))
				if ax != "":
					tag = Axes.label(ax)
					tc2 = Axes.color(ax)
			if tag != "":
				draw_string(fs, Vector2(x0 + 20 + inner - 100.0, y2 - 2), tag,
					HORIZONTAL_ALIGNMENT_LEFT, 96, 11,
					Color(tc2.r, tc2.g, tc2.b, a * 0.9))

		# ── 스크롤 막대 ──────────────────────────────────────────────────
		# 있어야 "아래에 더 있다" 가 보인다. 없으면 잘린 것과 구분이 안 된다.
		var ms := max_scroll()
		if ms > 0.0:
			var track := Rect2(x0 + inner + 24.0, ROW_TOP - 18.0, 4.0,
				float(fit) * ROW_H)
			draw_rect(track, Color(0.30, 0.36, 0.44, 0.5 * a))
			var frac := float(fit) / float(list.size())
			var th := track.size.y * frac
			var ty := track.position.y + (track.size.y - th) * (_scroll / ms)
			draw_rect(Rect2(track.position.x, ty, track.size.x, th),
				Color(0.55, 0.75, 0.95, 0.9 * a))


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
